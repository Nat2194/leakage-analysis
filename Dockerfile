FROM debian:latest

# Install dependencies
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y wget nodejs npm git

# Add Soufflé repository and install Soufflé
RUN wget https://souffle-lang.github.io/ppa/souffle-key.public -O /usr/share/keyrings/souffle-archive-keyring.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/souffle-archive-keyring.gpg] https://souffle-lang.github.io/ppa/ubuntu/ stable main" | tee /etc/apt/sources.list.d/souffle.list \
  && apt-get update \
  && apt-get upgrade -y \
  && wget -q http://ftp.de.debian.org/debian/pool/main/libf/libffi/libffi7_3.3-6_amd64.deb -O /tmp/libffi7_3.3-6_amd64.deb \
  && dpkg -i /tmp/libffi7_3.3-6_amd64.deb \
  && apt-get -f install \
  && apt install -y souffle

# Install Python 3.11 and necessary tools
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y python3.11 python3.11-venv python3-pip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Set up Python environment
WORKDIR /app
RUN python3.11 -m venv /venv
ENV PATH=/venv/bin:$PATH

# Copy source code to the container
COPY . /app/leakage-analysis/

# Initialize git submodules for Pyright
WORKDIR /app/leakage-analysis

RUN cat .gitmodules
RUN cat .git/config


# Copy the updated .gitmodules file into the container
COPY .gitmodules .gitmodules

RUN git submodule sync && \
    git submodule update --init --recursive && \
    git submodule foreach git pull origin main

# Set up Pyright
WORKDIR /app/leakage-analysis/pyright
RUN git show
RUN git remote show origin
RUN npm update && npm install && npm update && npm audit

RUN npm audit fix --force

# Build Pyright
WORKDIR /app/leakage-analysis/pyright/packages/pyright
RUN npm run build

# Set up main analysis
WORKDIR /app/leakage-analysis
RUN pip install --upgrade pip \
  && pip install -r requirements.txt

ENTRYPOINT ["python3", "-m", "src.main"]