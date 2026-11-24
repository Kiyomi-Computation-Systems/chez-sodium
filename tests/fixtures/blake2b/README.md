# blake2b-kat.txt

The BLAKE2 reference's keyed known answers, as fetched and unchanged:

- Source: https://raw.githubusercontent.com/BLAKE2/BLAKE2/ed1974ea83433eba7b2d95c5dcd9ac33cb847913/testvectors/blake2b-kat.txt
- Project: BLAKE2/BLAKE2, at commit `ed1974e`
- SHA-256: `82fcb3cabe8ff6e1452849e3b2a26a3631f1e2b51beb62ffb537892d2b3e364f`

256 entries, each with an input of 0 to 255 bytes, the one 64-byte key `00` to `3f`, and a 64-byte
hash. `tests/test-byte-verbs.sps` hashes every input through `blake2b` and compares.
