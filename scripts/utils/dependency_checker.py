"""Check R and package dependencies"""
import subprocess
from typing import Dict, List, Tuple
from rich.console import Console
from rich.table import Table

console = Console()


class DependencyChecker:
    """Check system and R package dependencies"""

    # Required R packages for different modules
    REQUIRED_R_PACKAGES = {
        "core": [
            "RSQLite",
            "DBI",
            "dplyr",
            "tidyr",
            "stringr",
            "jsonlite",
            "optparse",
        ],
        "plotting": [
            "ggplot2",
            "RColorBrewer",
            "gridExtra",
            "ggrepel",
        ],
        "statistics": [
            "poolr",  # Fisher's method
            "stats",
        ],
        "enrichment": [
            "WebGestaltR",
        ],
        "tables": [
            "reactable",
            "DT",
            "kableExtra",
        ],
    }

    @staticmethod
    def check_r_installed() -> Tuple[bool, str]:
        """
        Check if R is installed

        Returns:
            Tuple of (is_installed, version_string)
        """
        try:
            result = subprocess.run(
                ["Rscript", "--version"],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0:
                # Parse version from output
                version_line = result.stderr.strip() if result.stderr else result.stdout.strip()
                return True, version_line
            else:
                return False, ""
        except FileNotFoundError:
            return False, ""
        except subprocess.TimeoutExpired:
            return False, "Timeout checking R version"

    @staticmethod
    def check_r_packages(packages: List[str] = None) -> Dict[str, bool]:
        """
        Check if required R packages are installed

        Args:
            packages: List of package names to check (checks all if None)

        Returns:
            Dictionary mapping package names to installation status
        """
        if packages is None:
            # Check all required packages
            packages = []
            for pkg_list in DependencyChecker.REQUIRED_R_PACKAGES.values():
                packages.extend(pkg_list)
            packages = list(set(packages))  # Remove duplicates

        if not packages:
            return {}

        # Build R code to check packages
        check_script = f"""
        packages <- c({','.join(f'"{pkg}"' for pkg in packages)})
        installed <- sapply(packages, function(p) {{
            requireNamespace(p, quietly = TRUE)
        }})
        names(installed) <- packages

        # Check if jsonlite is available for output
        if (requireNamespace("jsonlite", quietly = TRUE)) {{
            cat(jsonlite::toJSON(installed, auto_unbox = TRUE))
        }} else {{
            # Fallback to simple output
            cat("{{")
            for (i in seq_along(packages)) {{
                cat(sprintf('"%s":%s', packages[i],
                    ifelse(installed[i], "true", "false")))
                if (i < length(packages)) cat(",")
            }}
            cat("}}")
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
                import json
                try:
                    return json.loads(result.stdout)
                except json.JSONDecodeError:
                    # Parsing failed, assume all not installed
                    return {pkg: False for pkg in packages}
            else:
                return {pkg: False for pkg in packages}
        except Exception:
            return {pkg: False for pkg in packages}

    @staticmethod
    def check_all_dependencies(verbose: bool = True) -> bool:
        """
        Check all dependencies and print status

        Args:
            verbose: Print detailed status (default: True)

        Returns:
            True if all dependencies are satisfied
        """
        all_ok = True

        if verbose:
            console.print("\n[cyan]Checking dependencies...[/cyan]\n")

        # Check R
        r_installed, r_version = DependencyChecker.check_r_installed()

        if r_installed:
            if verbose:
                console.print(f"[green]✓[/green] R is installed: {r_version}")
        else:
            if verbose:
                console.print("[red]✗[/red] R is not installed")
                console.print("  Install R from: https://www.r-project.org/")
            all_ok = False
            return all_ok  # Can't check packages without R

        # Check R packages by category
        if verbose:
            console.print()

        for category, packages in DependencyChecker.REQUIRED_R_PACKAGES.items():
            package_status = DependencyChecker.check_r_packages(packages)

            if package_status:
                missing = [pkg for pkg, installed in package_status.items() if not installed]

                if not missing:
                    if verbose:
                        console.print(
                            f"[green]✓[/green] {category.capitalize()} packages "
                            f"({len(package_status)} packages)"
                        )
                else:
                    if verbose:
                        console.print(
                            f"[yellow]![/yellow] {category.capitalize()} packages: "
                            f"Missing {len(missing)}/{len(package_status)}"
                        )
                        for pkg in missing:
                            console.print(f"    [red]✗[/red] {pkg}")
                    all_ok = False
            else:
                if verbose:
                    console.print(f"[red]✗[/red] Could not check {category} packages")
                all_ok = False

        # Print installation instructions if needed
        if not all_ok and verbose:
            console.print("\n[yellow]Installation Instructions:[/yellow]")
            console.print("  Run the package installation script:")
            console.print("    [cyan]Rscript scripts/r_analysis/install_packages.R[/cyan]")
            console.print("\n  Or install manually in R:")
            console.print("    [cyan]install.packages(c('RSQLite', 'dplyr', 'ggplot2', ...))[/cyan]")

        return all_ok

    @staticmethod
    def check_module_dependencies(module: str, verbose: bool = True) -> bool:
        """
        Check dependencies for a specific module

        Args:
            module: Module name (explore, compare, integrate)
            verbose: Print detailed status (default: True)

        Returns:
            True if all module dependencies are satisfied
        """
        # Map modules to required package categories
        module_requirements = {
            "explore": ["core", "plotting", "statistics", "enrichment"],
            "compare": ["core", "plotting", "statistics"],
            "integrate": ["core", "statistics"],
        }

        if module not in module_requirements:
            if verbose:
                console.print(f"[red]Unknown module: {module}[/red]")
            return False

        # Check R first
        r_installed, r_version = DependencyChecker.check_r_installed()
        if not r_installed:
            if verbose:
                console.print("[red]✗[/red] R is not installed")
            return False

        # Check required packages for this module
        required_categories = module_requirements[module]
        all_packages = []
        for category in required_categories:
            all_packages.extend(DependencyChecker.REQUIRED_R_PACKAGES.get(category, []))

        all_packages = list(set(all_packages))  # Remove duplicates
        package_status = DependencyChecker.check_r_packages(all_packages)

        missing = [pkg for pkg, installed in package_status.items() if not installed]

        if verbose:
            console.print(f"\n[cyan]Dependencies for '{module}' module:[/cyan]\n")

            if not missing:
                console.print(f"[green]✓[/green] All {len(all_packages)} required packages installed")
            else:
                console.print(f"[yellow]![/yellow] Missing {len(missing)} packages:")
                for pkg in missing:
                    console.print(f"    [red]✗[/red] {pkg}")

        return len(missing) == 0

    @staticmethod
    def print_package_summary() -> None:
        """Print summary table of all required packages"""
        console.print("\n[cyan]Required R Packages Summary[/cyan]\n")

        # Create table
        table = Table(show_header=True, header_style="bold cyan")
        table.add_column("Category", style="cyan")
        table.add_column("Packages", style="white")
        table.add_column("Count", justify="right", style="green")

        for category, packages in DependencyChecker.REQUIRED_R_PACKAGES.items():
            table.add_row(
                category.capitalize(),
                ", ".join(packages[:3]) + ("..." if len(packages) > 3 else ""),
                str(len(packages))
            )

        console.print(table)

        # Check installation status
        all_packages = []
        for pkg_list in DependencyChecker.REQUIRED_R_PACKAGES.values():
            all_packages.extend(pkg_list)
        all_packages = list(set(all_packages))

        console.print(f"\nTotal unique packages: {len(all_packages)}")
        console.print("\nTo install all packages, run:")
        console.print("  [cyan]Rscript scripts/r_analysis/install_packages.R[/cyan]")

    @staticmethod
    def get_missing_packages() -> List[str]:
        """
        Get list of missing packages

        Returns:
            List of package names that are not installed
        """
        all_packages = []
        for pkg_list in DependencyChecker.REQUIRED_R_PACKAGES.values():
            all_packages.extend(pkg_list)
        all_packages = list(set(all_packages))

        package_status = DependencyChecker.check_r_packages(all_packages)
        return [pkg for pkg, installed in package_status.items() if not installed]

    @staticmethod
    def quick_check() -> bool:
        """
        Quick dependency check (non-verbose)

        Returns:
            True if all dependencies satisfied, False otherwise
        """
        return DependencyChecker.check_all_dependencies(verbose=False)
