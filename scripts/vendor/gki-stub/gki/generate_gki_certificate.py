# Ubuntu's `mkbootimg` package (verified: 1:34.0.4-1build3, noble/universe)
# ships /usr/bin/mkbootimg importing `gki.generate_gki_certificate`
# unconditionally, but never packages the `gki` module itself -- an upstream
# packaging gap, not a real dependency: mkbootimg only calls this function
# when --gki_signing_key/--gki_signing_algorithm are both passed, which
# scripts/repack-boot.sh never does. This stub exists purely to satisfy the
# import; PYTHONPATH is pointed at scripts/vendor/gki-stub when invoking
# mkbootimg. It must never actually be called.


def generate_gki_certificate(*_args, **_kwargs):
    raise NotImplementedError(
        "gki.generate_gki_certificate is a stub (see comment above) -- "
        "pass --gki_signing_key/--gki_signing_algorithm only if you vendor "
        "the real module from AOSP's system/tools/mkbootimg source"
    )
