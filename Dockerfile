### Stage 1: Build patched Tamarin variants from source ########################
# Each variant pins its own stack resolver in stack.yaml, so `stack setup`
# is run per project rather than up front.

FROM haskell:latest AS tamarin-builder
RUN apt-get update && apt-get install -y patch && rm -rf /var/lib/apt/lists/*

COPY vendors/patches/ /patches/
COPY vendors/tamarin-prover/    /build/tamarin-prover/
COPY vendors/tamarin-unchained/ /build/tamarin-unchained/
RUN for d in /build/tamarin-prover /build/tamarin-unchained; do \
      (cd "$d" && for p in /patches/*.patch; do patch -p1 < "$p"; done) ; \
    done
RUN cd /build/tamarin-prover    && stack setup --install-ghc && stack install --local-bin-path /out/tamarin-prover
RUN cd /build/tamarin-unchained && stack setup --install-ghc && stack install --local-bin-path /out/tamarin-unchained

### Stage 2: Final image (copies Tamarin binaries from Stage 1) ################

FROM ocaml/opam:debian-12-ocaml-5.1

WORKDIR /home/opam/redx

# --- Core toolchain (required for all backends) ---
RUN opam install -y dune menhir ocamlfind yojson && opam clean

# --- ProVerif backend ---
# lablgtk (a ProVerif GUI dependency) requires GTK2 system libraries
RUN sudo apt-get update && sudo apt-get install -y curl pkg-config libgtk2.0-dev \
    && sudo rm -rf /var/lib/apt/lists/*
RUN opam install -y lablgtk && opam clean
# RUN opam install -y proverif && opam clean
RUN curl -L https://bblanche.gitlabpages.inria.fr/proverif/proverif2.05.tar.gz \
    | tar -xzf - -C /tmp \
    && cd /tmp/proverif2.05 && eval $(opam env) && ./build \
    && sudo cp proverif /usr/local/bin/ \
    && rm -rf /tmp/proverif2.05

# --- Tamarin + Tamarin-Unchained backends ---
# Maude is required at runtime by both Tamarin variants. The binaries are
# built (and our --no-compress patch applied) in Stage 1; see vendors/patches/.
RUN sudo apt-get update && sudo apt-get install -y maude graphviz \
    && sudo rm -rf /var/lib/apt/lists/*

# Copy source
COPY --chown=opam:opam . .

# Place the patched binaries where the ./redx wrapper expects
# (vendors/<variant>/out/), so the container and a local install resolve the
# Tamarin binary identically. After the source copy so it isn't clobbered.
COPY --from=tamarin-builder /out/tamarin-prover/tamarin-prover \
    vendors/tamarin-prover/out/tamarin-prover
COPY --from=tamarin-builder /out/tamarin-unchained/tamarin-prover \
    vendors/tamarin-unchained/out/tamarin-prover

# Build redx
RUN eval $(opam env) && dune build

ENTRYPOINT ["bash", "redx"]