FROM ocaml/opam:debian-12-ocaml-5.1

RUN sudo apt-get update && sudo apt-get install -y \
	build-essential \
	git \
	nodejs \
	npm \
	pkg-config \
	libgmp-dev \
    libev-dev \
    libsqlite3-dev \
    zlib1g-dev \
	&& sudo rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY src/ .
COPY static/css/ ./static/css/
COPY static/assets ./static/css/ 

RUN opam init -y --disable-sandboxing --bare

RUN opam switch create 5.1.0
RUN eval $(opam env) && \
	opam install -y \
	dune \
    eliom \
    ocsigenserver \
    ocsigen-start \
    ocsipersist-sqlite \
    ocsigen-toolkit \
    js_of_ocaml \
    js_of_ocaml-ppx \
    js_of_ocaml-lwt \
    lwt \
    tyxml

EXPOSE 8080

CMD ["sh", "-c", "eval $(opam env) && dune build && dune exec h42n42"]