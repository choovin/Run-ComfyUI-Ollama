FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS build

ARG LLAMACPP_PR=19460

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      cmake \
      ninja-build \
      build-essential && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/ggml-org/llama.cpp.git

WORKDIR /src/llama.cpp
RUN git fetch origin pull/${LLAMACPP_PR}/head:pr-${LLAMACPP_PR} && \
    git checkout pr-${LLAMACPP_PR}

RUN cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DGGML_CUDA=ON \
      -DLLAMA_BUILD_SERVER=ON && \
    cmake --build build --target llama-server -j

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      libgomp1 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /src/llama.cpp/build/bin/ /opt/llama/bin/

ENV PATH="/opt/llama/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/llama/bin:${LD_LIBRARY_PATH}"

WORKDIR /models
EXPOSE 8080

ENTRYPOINT ["llama-server"]
