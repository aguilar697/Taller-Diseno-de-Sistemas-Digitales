"""Copia Standalone 9.5 y aplica solo el backport de alineacion del trap.

No modifica AMD ni reutiliza una salida existente. Vitis 2026.1 solamente.
Origen del redondeo: AMD embeddedsw 8b60843923226004179ba4479a737382e8bde4d9.
Backport local: validacion estatica, no prueba funcional en FPGA.
"""
import argparse
import hashlib
import json
import re
import shutil
import stat
from pathlib import Path

ORIGINAL_SHA256 = "c228226efcaec75c3734742680136cf80efb2a9a94e3fb412b1b5562157ffa79"
OLD = "#define HANDLER_STACK_SIZE\t\t(REGSIZE * REGCOUNT + FPREGSIZE * FPREGCOUNT)"
NEW = "#define HANDLER_STACK_SIZE\t\t(((REGSIZE * REGCOUNT + FPREGSIZE * FPREGCOUNT) + 15) & ~15)"


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def prepare_local_bsp(standalone, repository):
    standalone, repository = Path(standalone).resolve(), Path(repository).resolve()
    git_root = Path(__file__).resolve().parents[3]
    if repository == git_root or git_root in repository.parents:
        raise ValueError("El BSP generado debe quedar fuera del repositorio Git")
    if repository == standalone or standalone in repository.parents:
        raise ValueError("La salida no puede estar dentro del BSP original")
    if standalone.parents[4] == repository or standalone.parents[4] in repository.parents:
        raise ValueError("No se permite generar archivos dentro de la instalacion AMD")
    if repository.exists():
        raise ValueError("La salida ya existe; no se aplica el parche dos veces")
    original = standalone / "src/riscv/trap_handler.S"
    metadata = (standalone / "data/standalone.mld").read_text(encoding="utf-8")
    if standalone.name != "standalone_v9_5" or not re.search(r"OPTION VERSION\s*=\s*9\.5;", metadata):
        raise ValueError("Se requiere Standalone 9.5 de Vitis 2026.1")
    if digest(original) != ORIGINAL_SHA256:
        raise ValueError("Hash AMD distinto: detenerse y revisar la version; no parchear")
    patch_file = Path(__file__).with_name("patches") / "standalone_9_5_trap_align16.patch"
    patch = patch_file.read_text(encoding="utf-8").splitlines()
    removed = [s[1:] for s in patch if s.startswith("-") and not s.startswith("---")]
    added = [s[1:] for s in patch if s.startswith("+") and not s.startswith("+++")]
    if removed != [OLD] or added != [NEW]:
        raise ValueError("El parche no contiene exclusivamente el cambio autorizado")
    text = original.read_bytes().decode("utf-8")
    if text.count(OLD) != 1 or NEW in text:
        raise ValueError("Fuente original inesperada o ya parcheada")
    target = repository / "lib/bsp/standalone_v9_5"
    shutil.copytree(standalone, target)
    handler = target / "src/riscv/trap_handler.S"
    handler.chmod(stat.S_IREAD | stat.S_IWRITE)
    handler.write_bytes(text.replace(OLD, NEW).encode("utf-8"))
    if digest(original) != ORIGINAL_SHA256:
        raise RuntimeError("La fuente original cambio durante la copia")
    result = {"standalone_version": "9.5", "tested_vitis": "2026.1",
              "upstream_commit": "8b60843923226004179ba4479a737382e8bde4d9",
              "original_sha256": ORIGINAL_SHA256, "patched_sha256": digest(handler),
              "patch_sha256": digest(patch_file), "functional_validation": "PENDIENTE"}
    (repository / "backport_manifest.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("standalone", type=Path)
    parser.add_argument("repository", type=Path)
    args = parser.parse_args()
    print(json.dumps(prepare_local_bsp(args.standalone, args.repository), indent=2))
