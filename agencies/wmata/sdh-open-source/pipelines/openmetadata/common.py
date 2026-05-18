from abc import ABC, abstractmethod
import time
import traceback
from urllib.parse import urlparse

from dagster import OpExecutionContext, ConfigurableResource, EnvVar
from metadata.utils.logger import ingestion_logger
from metadata.ingestion.api.steps import InvalidSourceException
from metadata.utils.execution_time_tracker import ExecutionTimeTracker

from metadata.workflow.metadata import MetadataWorkflow
from metadata.generated.schema.metadataIngestion.workflow import (
    WorkflowConfig,
    OpenMetadataWorkflowConfig,
    Sink,
    Source,
    Processor,
)
from metadata.generated.schema.entity.services.connections.metadata.openMetadataConnection import (
    OpenMetadataConnection,
)
from metadata.generated.schema.security.client.openMetadataJWTClientConfig import (
    OpenMetadataJWTClientConfig,
)

logger = ingestion_logger()


class _RequestLogger:
    """Wraps a requests.Session to log every HTTP call with timing."""

    def __init__(self, session, dagster_log, slow_threshold: float = 1.0):
        self._session = session
        self._log = dagster_log
        self._slow_threshold = slow_threshold
        self.request_log: list[dict] = []

    def request(self, method, url, **kwargs):
        path = urlparse(str(url)).path
        start = time.monotonic()
        resp = self._session.request(method, url, **kwargs)
        elapsed = time.monotonic() - start

        entry = {
            "method": method,
            "path": path,
            "status": resp.status_code,
            "elapsed": elapsed,
            "size": len(resp.content) if resp.content else 0,
        }
        self.request_log.append(entry)

        slow_tag = "SLOW " if elapsed >= self._slow_threshold else ""
        self._log.debug(
            f"{slow_tag}OMD request: {method} {path} "
            f"status={resp.status_code} elapsed={elapsed:.2f}s size={entry['size']}B"
        )

        return resp

    def __getattr__(self, name):
        return getattr(self._session, name)

    def log_summary(self):
        if not self.request_log:
            return

        total = len(self.request_log)
        total_time = sum(r["elapsed"] for r in self.request_log)
        slow = [r for r in self.request_log if r["elapsed"] >= self._slow_threshold]

        # Group by method + path
        by_endpoint: dict[str, list[float]] = {}
        for r in self.request_log:
            key = f"{r['method']} {r['path']}"
            by_endpoint.setdefault(key, []).append(r["elapsed"])

        self._log.debug(
            f"OMD HTTP summary: {total} requests, {total_time:.1f}s total, "
            f"{slow and len(slow) or 0} slow (>={self._slow_threshold}s)"
        )

        # Top 10 slowest endpoints by cumulative time
        ranked = sorted(by_endpoint.items(), key=lambda kv: sum(kv[1]), reverse=True)
        lines = []
        for endpoint, times in ranked[:10]:
            lines.append(
                f"  {endpoint}: calls={len(times)} "
                f"total={sum(times):.1f}s avg={sum(times) / len(times):.2f}s "
                f"max={max(times):.2f}s"
            )
        if lines:
            self._log.debug("OMD top endpoints by time:\n" + "\n".join(lines))


class OpenMetadataResource(ConfigurableResource):
    """Resource that provides OpenMetadata authentication.

    Parameters
    ----------
    api_url: str
        URL to OpenMetadata API endpoint
    api_token: str
        JWT for OpenMetadata IngestionBot

    Returns
    -------
    OpenMetadataResource
        Resource for use in Dagster
    """

    api_url: str = EnvVar("OPENMETADATA_API_URL")
    api_token: str = EnvVar("OPENMETADATA_API_TOKEN")


class IngestionError(Exception):
    """Custom exception for workflow errors with stack trace."""

    def __init__(self, name: str, error: str, stackTrace: str):
        self.name = name
        self.error = error
        self.stackTrace = stackTrace
        super().__init__(error)


class OpenMetadataIngestionOp(ABC):
    """Base class for OpenMetadata ingestion operations."""

    workflowClass: type[MetadataWorkflow] = MetadataWorkflow

    @abstractmethod
    def create_source_config(self, context: OpExecutionContext) -> Source:
        """Create source-specific configuration."""
        pass

    def create_processor_config(self, context: OpExecutionContext) -> Processor | None:
        """Create processor."""
        return None

    def create_workflow_config(
        self, context: OpExecutionContext
    ) -> OpenMetadataWorkflowConfig:
        """Create complete workflow configuration."""

        return OpenMetadataWorkflowConfig(
            source=self.create_source_config(context),
            sink=Sink(type="metadata-rest", config={}),
            processor=self.create_processor_config(context),
            workflowConfig=WorkflowConfig(
                openMetadataServerConfig=OpenMetadataConnection(
                    hostPort=context.resources.openmetadata_api.api_url,
                    authProvider="openmetadata",
                    securityConfig=OpenMetadataJWTClientConfig(
                        jwtToken=context.resources.openmetadata_api.api_token
                    ),
                )
            ),
        )

    def execute(self, context: OpExecutionContext):
        """Execute the metadata ingestion workflow."""
        req_logger = None
        try:
            workflow = self.workflowClass(config=self.create_workflow_config(context))

            # Wrap the SDK's HTTP session to log every request
            req_logger = self._install_request_logger(workflow, context)

            start = time.monotonic()
            workflow.execute()
            elapsed = time.monotonic() - start

            context.log.debug(f"OMD ingestion completed in {elapsed:.1f}s")

            # Log per-step record counts from the workflow
            for step in workflow.workflow_steps():
                status = step.status
                if not status:
                    continue
                step_name = type(step).__name__
                context.log.debug(
                    f"  {step_name}: "
                    f"records={status.records}, "
                    f"updated={status.updated_records}, "
                    f"filtered={status.filtered}, "
                    f"failures={len(status.failures) if status.failures else 0}"
                )

            # Surface the SDK's per-step timing breakdown
            summary = ExecutionTimeTracker().get_summary()
            if summary:
                context.log.debug(f"OMD execution time breakdown:\n{summary}")

            # Log detailed HTTP request summary
            if req_logger:
                req_logger.log_summary()

            workflow.raise_from_status()
            workflow.print_status()
            workflow.stop()

            return True
        except Exception as e:
            # Still log HTTP summary on failure
            if req_logger:
                req_logger.log_summary()
            logger.debug(traceback.format_exc())
            if isinstance(e, InvalidSourceException):
                raise e
            raise IngestionError(
                name="Metadata Ingestion",
                error=f"Error during metadata ingestion: {e}",
                stackTrace=traceback.format_exc(),
            )

    @staticmethod
    def _install_request_logger(workflow, context: OpExecutionContext):
        """Exposes requests being made to OpenMetaData service to logs in the Dagster UI.  Useful for debugging"""
        try:
            rest_client = workflow.metadata.client
            original_session = rest_client._session
            req_logger = _RequestLogger(original_session, context.log)
            rest_client._session = req_logger
            context.log.debug(
                f"OMD request logging enabled (slow threshold: {req_logger._slow_threshold}s)"
            )
            return req_logger
        except Exception as e:
            context.log.warning(f"Could not install OMD request logger: {e}")
            return None
