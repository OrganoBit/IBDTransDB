"""Handle plot file management and organization"""
from pathlib import Path
from typing import Optional, List
import shutil
from datetime import datetime


class PlotHandler:
    """Manage plot file paths and organization"""

    def __init__(self, output_dir: Optional[Path] = None):
        """
        Initialize plot handler

        Args:
            output_dir: Base directory for plot output
                       (default: outputs/plots in project root)
        """
        if output_dir is None:
            # Default to outputs/plots in project root
            project_root = Path(__file__).parent.parent.parent
            output_dir = project_root / "outputs" / "plots"

        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def save_plot(
        self,
        source_file: Path,
        plot_name: str,
        dataset_acc: Optional[str] = None,
        subdirectory: Optional[str] = None
    ) -> Path:
        """
        Save plot to organized location

        Args:
            source_file: Source plot file to copy
            plot_name: Name for the plot (without extension)
            dataset_acc: Dataset accession for organizing (optional)
            subdirectory: Additional subdirectory for organization (optional)

        Returns:
            Path to saved plot file
        """
        # Determine destination directory
        if dataset_acc and subdirectory:
            plot_dir = self.output_dir / dataset_acc / subdirectory
        elif dataset_acc:
            plot_dir = self.output_dir / dataset_acc
        elif subdirectory:
            plot_dir = self.output_dir / subdirectory
        else:
            plot_dir = self.output_dir

        plot_dir.mkdir(parents=True, exist_ok=True)

        # Preserve file extension
        extension = source_file.suffix
        dest_file = plot_dir / f"{plot_name}{extension}"

        # Copy file to destination
        shutil.copy(source_file, dest_file)

        return dest_file

    def save_plots(
        self,
        source_files: List[Path],
        dataset_acc: Optional[str] = None,
        subdirectory: Optional[str] = None
    ) -> List[Path]:
        """
        Save multiple plots to organized location

        Args:
            source_files: List of source plot files
            dataset_acc: Dataset accession for organizing (optional)
            subdirectory: Additional subdirectory for organization (optional)

        Returns:
            List of paths to saved plot files
        """
        saved_plots = []

        for source_file in source_files:
            # Use original filename without extension as plot name
            plot_name = source_file.stem
            dest_file = self.save_plot(
                source_file,
                plot_name,
                dataset_acc,
                subdirectory
            )
            saved_plots.append(dest_file)

        return saved_plots

    def get_plot_path(
        self,
        plot_name: str,
        dataset_acc: Optional[str] = None,
        subdirectory: Optional[str] = None,
        extension: str = "png",
        timestamp: bool = False
    ) -> Path:
        """
        Get path for new plot file

        Args:
            plot_name: Base name for the plot
            dataset_acc: Dataset accession for organizing (optional)
            subdirectory: Additional subdirectory for organization (optional)
            extension: File extension (default: png)
            timestamp: Add timestamp to filename (default: False)

        Returns:
            Path for new plot file
        """
        # Determine destination directory
        if dataset_acc and subdirectory:
            plot_dir = self.output_dir / dataset_acc / subdirectory
        elif dataset_acc:
            plot_dir = self.output_dir / dataset_acc
        elif subdirectory:
            plot_dir = self.output_dir / subdirectory
        else:
            plot_dir = self.output_dir

        plot_dir.mkdir(parents=True, exist_ok=True)

        # Add timestamp if requested
        if timestamp:
            ts = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"{plot_name}_{ts}.{extension}"
        else:
            filename = f"{plot_name}.{extension}"

        return plot_dir / filename

    def list_plots(
        self,
        dataset_acc: Optional[str] = None,
        subdirectory: Optional[str] = None,
        extension: Optional[str] = None
    ) -> List[Path]:
        """
        List existing plots

        Args:
            dataset_acc: Filter by dataset accession (optional)
            subdirectory: Filter by subdirectory (optional)
            extension: Filter by file extension (optional, e.g., "png")

        Returns:
            List of plot file paths
        """
        # Determine search directory
        if dataset_acc and subdirectory:
            search_dir = self.output_dir / dataset_acc / subdirectory
        elif dataset_acc:
            search_dir = self.output_dir / dataset_acc
        elif subdirectory:
            search_dir = self.output_dir / subdirectory
        else:
            search_dir = self.output_dir

        if not search_dir.exists():
            return []

        # Find plots
        if extension:
            pattern = f"*.{extension.lstrip('.')}"
            plots = list(search_dir.glob(pattern))
        else:
            # Find all image files
            plots = []
            for ext in ["png", "pdf", "svg", "jpg", "jpeg"]:
                plots.extend(search_dir.glob(f"*.{ext}"))

        return sorted(plots)

    def cleanup_old_plots(
        self,
        days: int = 7,
        dataset_acc: Optional[str] = None
    ) -> int:
        """
        Remove plots older than specified days

        Args:
            days: Remove plots older than this many days
            dataset_acc: Limit cleanup to specific dataset (optional)

        Returns:
            Number of files removed
        """
        import time

        # Determine search directory
        if dataset_acc:
            search_dir = self.output_dir / dataset_acc
        else:
            search_dir = self.output_dir

        if not search_dir.exists():
            return 0

        cutoff_time = time.time() - (days * 24 * 60 * 60)
        removed_count = 0

        # Find and remove old files
        for plot_file in search_dir.rglob("*"):
            if plot_file.is_file():
                if plot_file.stat().st_mtime < cutoff_time:
                    plot_file.unlink()
                    removed_count += 1

        return removed_count

    def create_subdirectory(
        self,
        subdirectory: str,
        dataset_acc: Optional[str] = None
    ) -> Path:
        """
        Create a subdirectory for organizing plots

        Args:
            subdirectory: Name of subdirectory to create
            dataset_acc: Create under dataset directory (optional)

        Returns:
            Path to created subdirectory
        """
        if dataset_acc:
            subdir_path = self.output_dir / dataset_acc / subdirectory
        else:
            subdir_path = self.output_dir / subdirectory

        subdir_path.mkdir(parents=True, exist_ok=True)
        return subdir_path

    def get_plot_size(self, plot_file: Path) -> Optional[int]:
        """
        Get size of plot file in bytes

        Args:
            plot_file: Path to plot file

        Returns:
            File size in bytes, or None if file doesn't exist
        """
        if plot_file.exists():
            return plot_file.stat().st_size
        return None

    def format_plot_path_display(self, plot_path: Path) -> str:
        """
        Format plot path for display (relative to output dir)

        Args:
            plot_path: Full path to plot

        Returns:
            Formatted path string relative to output directory
        """
        try:
            relative = plot_path.relative_to(self.output_dir)
            return str(relative)
        except ValueError:
            # Path is not relative to output_dir
            return str(plot_path)
