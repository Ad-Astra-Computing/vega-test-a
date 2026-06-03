{
  description = "Vega staging reproduction test fixture: a self-building flake.";

  # Pinned so the build is deterministic and reproducible by Vega's worker.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/50ab793786d9de88ee30ec4e4c24fb4236fc2674";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # `figlet` is the attested attr; the worker rebuilds github:.../vega-test-a#figlet
      # from source and must get this exact output.
      packages.${system} = {
        figlet = pkgs.figlet;
        hello = pkgs.hello;
        # A deterministic, repo-unique output: no other tenant builds it, so it
        # stays at one distinct tenant in the pending queue (leasable by the
        # reproduction worker) instead of promoting on agreement.
        probe = pkgs.runCommand "vega-repro-e2e-probe-1" { } ''
          mkdir -p "$out"
          printf 'vega reproduction worker e2e probe v1\n' > "$out/probe.txt"
        '';
        # Intentionally NON-reproducible: the content differs every build, so an
        # independent rebuild disagrees on narHash. Exercises the reproduction
        # worker's divergence path (same store path, different bytes).
        flaky = pkgs.runCommand "vega-flaky-probe" { } ''
          mkdir -p "$out"
          date +%s%N > "$out/nondeterministic.txt"
        '';
        # A larger, deterministic output: it copies a package in, so its closure
        # pulls real dependencies (a few tens of MB). Exercises the reproduction
        # worker's chunked closure retrieval on a non-trivial closure.
        bignar = pkgs.runCommand "vega-bignar-probe" { } ''
          mkdir -p "$out"
          cp -r ${pkgs.hello} "$out/hello"
          echo v2 > "$out/marker"
        '';
        default = pkgs.figlet;
      };
    };
}
