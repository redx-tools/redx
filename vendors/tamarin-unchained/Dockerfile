FROM haskell:latest

WORKDIR /usr/src/tamarin
COPY . .

RUN mkdir out

RUN stack setup --install-ghc
RUN stack install --local-bin-path ./out
