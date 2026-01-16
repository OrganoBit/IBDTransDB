"""R script execution and result handling"""
import subprocess
import json
from pathlib import Path
from typing import Dict, Any, Optional, List
import tempfile


def get_r_scripts_dir() -> Path:
    """
    Get path to R scripts directory

    Returns:
        Path to scripts/r_analysis directory
    """
    # From utils/r_executor.py, go up two levels to scripts/, then into r_analysis/
    return Path(__file__).parent.parent / "r_analysis"


class RScriptExecutor:
    """Execute R scripts and handle results"""

    # Timeout settings (in seconds)
    TIMEOUT_SECONDS = {
        "pca_analysis": 300,      # 5 minutes
        "dge_analysis": 180,      # 3 minutes
        "volcano_plot": 180,      # 3 minutes
        "enrichment": 600,        # 10 minutes (WebGestaltR can be slow)
        "meta_analysis": 900,     # 15 minutes
        "target_ranking": 1200,   # 20 minutes
        "default": 300,           # 5 minutes default
    }

    def __init__(self, db_path: Path, r_scripts_dir: Path):
        """
        Initialize R script executor

        Args:
            db_path: Path to IBDTransDB.db
            r_scripts_dir: Path to r_analysis/ directory
        """
        self.db_path = db_path
        self.r_scripts_dir = r_scripts_dir
        self.check_r_available()

    def check_r_available(self) -> bool:
        """
        Check if R and Rscript are available

        Returns:
            True if R is available

        Raises:
            RuntimeError: If R is not installed or not in PATH
        """
        try:
            result = subprocess.run(
                ["Rscript", "--version"],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode != 0:
                raise RuntimeError("Rscript not found or returned error")
            return True
        except FileNotFoundError:
            raise RuntimeError(
                "R is not installed or not in PATH. "
                "Please install R from https://www.r-project.org/"
            )
        except subprocess.TimeoutExpired:
            raise RuntimeError("Rscript check timed out")

    def check_r_packages(self, required_packages: List[str]) -> Dict[str, bool]:
        """
        Check if required R packages are installed

        Args:
            required_packages: List of package names to check

        Returns:
            Dictionary mapping package names to installation status
        """
        # Build R code to check packages
        check_script = f"""
        packages <- c({','.join(f'"{pkg}"' for pkg in required_packages)})
        installed <- sapply(packages, function(p) {{
            requireNamespace(p, quietly = TRUE)
        }})
        names(installed) <- packages

        # Check if jsonlite is available for output
        if (requireNamespace("jsonlite", quietly = TRUE)) {{
            cat(jsonlite::toJSON(installed, auto_unbox = TRUE))
        }} else {{
            # Fallback to simple output
            for (i in seq_along(packages)) {{
                cat(sprintf('"%s":%s', packages[i],
                    ifelse(installed[i], "true", "false")))
                if (i < length(packages)) cat(",")
            }}
        }}
        """

        try:
            result = subprocess.run(
                ["Rscript", "-e", check_script],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0 and result.stdout.strip():
                try:
                    return json.loads(result.stdout)
                except json.JSONDecodeError:
                    # Fallback parsing
                    return {pkg: False for pkg in required_packages}
            else:
                return {pkg: False for pkg in required_packages}
        except Exception:
            return {pkg: False for pkg in required_packages}

    def execute_r_script(
        self,
        script_name: str,
        args: Dict[str, Any],
        output_dir: Optional[Path] = None,
        timeout: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Execute R script with arguments

        Args:
            script_name: Name of R script relative to r_scripts_dir
                        (e.g., "explore/pca_analysis.R")
            args: Dictionary of arguments to pass to R script
            output_dir: Directory for output files (plots, data)
            timeout: Timeout in seconds (uses script-specific default if None)

        Returns:
            Dictionary with:
                - return_code: Exit code from R script
                - stdout: Standard output
                - stderr: Standard error
                - output_dir: Path to output directory
                - data: Parsed JSON data if available
                - files: Dictionary of generated files by type

        Raises:
            FileNotFoundError: If R script doesn't exist
            RScriptError: If R script execution fails
            subprocess.TimeoutExpired: If execution times out
        """
        script_path = self.r_scripts_dir / script_name

        if not script_path.exists():
            raise FileNotFoundError(f"R script not found: {script_path}")

        # Create temporary output directory if not specified
        if output_dir is None:
            output_dir = Path(tempfile.mkdtemp(prefix="ibdtrans_"))
        else:
            output_dir.mkdir(parents=True, exist_ok=True)

        # Determine timeout
        if timeout is None:
            # Extract script type from name for timeout lookup
            script_type = script_path.stem  # e.g., "pca_analysis"
            timeout = self.TIMEOUT_SECONDS.get(script_type,
                                               self.TIMEOUT_SECONDS["default"])

        # Build R command with arguments
        cmd = ["Rscript", str(script_path)]

        # Pass database path
        cmd.extend(["--db-path", str(self.db_path)])

        # Pass output directory
        cmd.extend(["--output-dir", str(output_dir)])

        # Pass other arguments
        for key, value in args.items():
            if value is None:
                continue

            cmd.append(f"--{key.replace('_', '-')}")

            if isinstance(value, bool):
                # Boolean flags don't need values (presence = TRUE)
                continue
            elif isinstance(value, list):
                cmd.append(",".join(str(v) for v in value))
            else:
                cmd.append(str(value))

        # Execute R script
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
        except subprocess.TimeoutExpired as e:
            raise subprocess.TimeoutExpired(
                cmd=cmd,
                timeout=timeout,
                output=f"R script timed out after {timeout} seconds"
            )

        # Parse results
        output = {
            "return_code": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "output_dir": output_dir
        }

        # Check for errors
        if result.returncode != 0:
            error_msg = result.stderr if result.stderr else "Unknown error"
            raise RScriptError(
                f"R script failed: {script_name}\n"
                f"Return code: {result.returncode}\n"
                f"Error: {error_msg}"
            )

        # Parse JSON output if present
        stdout_stripped = result.stdout.strip()
        if stdout_stripped.startswith("{") or stdout_stripped.startswith("["):
            try:
                output["data"] = json.loads(stdout_stripped)
            except json.JSONDecodeError as e:
                # JSON parsing failed, but script succeeded
                # Store raw output instead
                output["data"] = {"raw": stdout_stripped}

        # Find generated files
        output["files"] = self._find_output_files(output_dir)

        return output

    def execute_r_code(
        self,
        r_code: str,
        timeout: int = 30
    ) -> subprocess.CompletedProcess:
        """
        Execute R code directly (useful for checks)

        Args:
            r_code: R code string to execute
            timeout: Timeout in seconds

        Returns:
            subprocess.CompletedProcess object
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result

    def _find_output_files(self, output_dir: Path) -> Dict[str, List[Path]]:
        """
        Find generated output files by type

        Args:
            output_dir: Directory to search

        Returns:
            Dictionary with keys: plots, tables, data
        """
        files = {
            "plots": [],
            "tables": [],
            "data": []
        }

        if not output_dir.exists():
            return files

        # Find plots
        for ext in ["*.png", "*.pdf", "*.svg"]:
            files["plots"].extend(output_dir.glob(ext))

        # Find tables
        for ext in ["*.csv", "*.tsv", "*.txt"]:
            files["tables"].extend(output_dir.glob(ext))

        # Find data files
        for ext in ["*.json", "*.rds", "*.RData"]:
            files["data"].extend(output_dir.glob(ext))

        return files


class RScriptError(Exception):
    """Exception raised when R script execution fails"""
    pass
