FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# System dependencies: Python 3.12, R 4.5 from CRAN + tidyverse/Shiny system libs
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        gnupg \
        curl \
        ca-certificates \
        python3.12 \
        python3.12-venv \
        python3-pip \
    && curl -sSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
       | gpg --dearmor -o /usr/share/keyrings/cran.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cran.gpg] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" \
       >> /etc/apt/sources.list.d/cran.list \
    && apt-get update && apt-get install -y --no-install-recommends \
       r-base \
       r-base-dev \
       # tidyverse / ggplot2 system deps
       libssl-dev \
       libcurl4-openssl-dev \
       libxml2-dev \
       libfontconfig1-dev \
       libharfbuzz-dev \
       libfribidi-dev \
       libfreetype6-dev \
       libpng-dev \
       libtiff5-dev \
       libjpeg-dev \
       # Shiny / htmlwidgets system deps
       pandoc \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Python environment (venv)
# ---------------------------------------------------------------------------
RUN python3.12 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---------------------------------------------------------------------------
# R environment (renv)
# ---------------------------------------------------------------------------
ENV RENV_PATHS_LIBRARY=/renv/library \
    R_LIBS_USER=/renv/library \
    # Use Posit Package Manager for pre-built Linux binaries — much faster than
    # compiling from source, and avoids version mismatches with system libraries.
    RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.posit.co/cran/__linux__/noble/latest

RUN Rscript -e "install.packages('renv', repos='https://cloud.r-project.org')"

COPY install_base_packages.R renv.lock ./

# Restore from lock file; fall back to direct install if lock is absent/stale.
# Hash validation is disabled so the boilerplate lock works before users
# regenerate it with `Rscript install_base_packages.R` in their own build.
RUN Rscript -e " \
  options(renv.config.hash.validate = FALSE); \
  if (file.exists('renv.lock')) { \
    renv::restore( \
      lockfile = 'renv.lock', \
      library  = Sys.getenv('RENV_PATHS_LIBRARY'), \
      clean    = FALSE, \
      prompt   = FALSE \
    ) \
  } else { \
    source('install_base_packages.R') \
  } \
"

# ---------------------------------------------------------------------------
# Runtime entrypoint — selects Dash or Shiny via APP_TYPE env var
# ---------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

# Cloud Run injects PORT; default to 8080
ENV PORT=8080

ENTRYPOINT ["/entrypoint.sh"]
