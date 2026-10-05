(lang dune 3.20)

(name redx)

(generate_opam_files true)

(using menhir 2.1)

(authors
 "Prashant Agrawal"
 "Manuel Barbosa"
 "Gilles Barthe"
 "Adrien Koutsos"
 "Justine Sauvage")

(maintainers "Prashant Agrawal")

(license MIT)

(package
 (name redx)
 (synopsis "Reduction synthesis for cryptographic proofs")
 (description "Reduction synthesis for cryptographic proofs")
 (depends ocaml (dune (>= 3.20)) menhir yojson)
 (tags
  ("add topics" "to describe" your project)))
