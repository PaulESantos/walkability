# read the DESCRIPTION file
desc <- read.dcf("DESCRIPTION")

if (!"SystemRequirements" %in% colnames(desc)) {
  fmt <- c(
    "`SystemRequirements` not found in `DESCRIPTION`.",
    "Please specify `SystemRequirements: Cargo (Rust's package manager), rustc`"
  )
  stop(paste(fmt, collapse = "\n"))
}

# extract system requirements
sysreqs <- desc[, "SystemRequirements"]

# check that cargo and rustc is found
if (!grepl("cargo", sysreqs, ignore.case = TRUE)) {
  stop("You must specify `Cargo (Rust's package manager)` in your `SystemRequirements`")
}

if (!grepl("rustc", sysreqs, ignore.case = TRUE)) {
  stop("You must specify `Cargo (Rust's package manager), rustc` in your `SystemRequirements`")
}

# Keep these values synchronized with `rust-version` in src/rust/Cargo.toml.
required_cargo <- "1.80.0"
required_rustc <- "1.80.0"

# perform checks for the presence of rustc and cargo on the OS
no_cargo_msg <- c(
  "----------------------- [CARGO NOT FOUND]--------------------------",
  "The 'cargo' command was not found on the PATH. Please install Cargo",
  "from: https://rust-lang.org/tools/install/",
  "",
  "Alternatively, you may install Cargo from your OS package manager:",
  " - Debian/Ubuntu: apt-get install cargo",
  " - Fedora/CentOS: dnf install cargo",
  " - macOS: brew install rust",
  "-------------------------------------------------------------------"
)

no_rustc_msg <- c(
  "----------------------- [RUST NOT FOUND]---------------------------",
  "The 'rustc' compiler was not found on the PATH. Please install",
  paste("Rust", required_rustc, "or higher from:"),
  "https://rust-lang.org/tools/install/",
  "",
  "Alternatively, you may install Rust from your OS package manager:",
  " - Debian/Ubuntu: apt-get install rustc",
  " - Fedora/CentOS: dnf install rustc",
  " - macOS: brew install rust",
  "-------------------------------------------------------------------"
)

# Search both the system PATH and the standard per-user Cargo location. The
# platform-specific separator is essential on Windows.
cargo_bin <- file.path(path.expand("~"), ".cargo", "bin")
Sys.setenv(PATH = paste(Sys.getenv("PATH"), cargo_bin, sep = .Platform$path.sep))

run_version_command <- function(command, missing_message) {
  executable <- Sys.which(command)
  if (!nzchar(executable)) {
    stop(paste(missing_message, collapse = "\n"))
  }

  output <- suppressWarnings(system2(executable, "--version", stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(output, "status")) || !length(output)) {
    stop(paste(missing_message, collapse = "\n"))
  }
  output
}

rustc_version <- run_version_command("rustc", no_rustc_msg)
cargo_version <- run_version_command("cargo", no_cargo_msg)

# helper function to extract versions
extract_semver <- function(ver) {
  if (grepl("\\d+\\.\\d+(\\.\\d+)?", ver)) {
    sub(".*?(\\d+\\.\\d+(\\.\\d+)?).*", "\\1", ver)
  } else {
    NA
  }
}

# extract current version
current_rust_version <- extract_semver(rustc_version)
current_cargo_version <- extract_semver(cargo_version)

if (is.na(current_cargo_version) || utils::compareVersion(required_cargo, current_cargo_version) == 1) {
  fmt <- paste0(
    "\n----------------- [UNSUPPORTED CARGO VERSION]-----------------\n",
    "- Minimum supported Cargo version is %s.\n",
    "- Installed Cargo version is %s.\n",
    "---------------------------------------------------------------"
  )
  stop(sprintf(fmt, required_cargo, paste(cargo_version, collapse = " ")))
}

# perform check
if (is.na(current_rust_version) || utils::compareVersion(required_rustc, current_rust_version) == 1) {
  fmt <- paste0(
    "\n------------------ [UNSUPPORTED RUST VERSION]------------------\n",
    "- Minimum supported Rust version is %s.\n",
    "- Installed Rust version is %s.\n",
    "---------------------------------------------------------------"
  )
  stop(sprintf(fmt, required_rustc, paste(rustc_version, collapse = " ")))
}

# print the versions
versions_fmt <- "Using %s\nUsing %s"
message(sprintf(versions_fmt, cargo_version, rustc_version))
