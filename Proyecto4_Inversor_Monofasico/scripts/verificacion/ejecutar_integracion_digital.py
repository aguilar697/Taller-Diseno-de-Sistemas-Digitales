"""XSim funcional: pruebas PWM existentes e integracion AXI con XADC digital.

Todos los productos se guardan en una carpeta externa nueva. No ejecuta PR/CPU.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('salida', type=Path)
    parser.add_argument('--vivado-home', type=Path, required=True)
    parser.add_argument('--solo-integracion', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.salida.resolve()
    if output == root.parent or root.parent in output.parents or output.exists():
        raise ValueError('La salida debe ser externa y nueva')
    output.mkdir(parents=True)
    pwm = root / 'src/design/pwm'
    adc = root / 'src/design/adc'
    tb = root / 'src/testbench'
    sources_pwm = [pwm / (name + '.sv') for name in
                   ('pwm_deadtime', 'pwm_core', 'pwm_axi_lite', 'pwm_system_axi')]
    tops = ['tb_pwm_deadtime', 'tb_pwm_core', 'tb_pwm_axi', 'tb_pwm_adc', 'tb_pwm_timing',
            'tb_pwm_adc_axi']
    if args.solo_integracion:
        tops = ['tb_pwm_adc_axi']
    results = []
    for top in tops:
        target = output / top
        target.mkdir()
        sources = list(sources_pwm)
        if top == 'tb_pwm_adc':
            sources.append(adc / 'adc_control.sv')
        if top == 'tb_pwm_adc_axi':
            sources += [adc / (name + '.sv') for name in
                        ('adc_control', 'adc_top', 'adc_axi_lite', 'adc_system_axi')]
            sources += [tb / 'integration/xadc_digital_model.sv', tb / 'integration/tb_pwm_adc_axi.sv']
        else:
            sources.append(tb / 'pwm' / (top + '.sv'))
        binaries = {name: str(args.vivado_home / 'bin' / (name + '.bat'))
                    for name in ('xvlog', 'xelab', 'xsim')}
        commands = [[binaries['xvlog'], '--sv', '-i', str(tb / 'pwm'),
                     *map(str, sources), '-log', 'compile.log'],
                    [binaries['xelab'], '--debug', 'typical', '--snapshot', top, 'work.' + top,
                     '-log', 'elaborate.log'],
                    [binaries['xsim'], top, '-runall', '-log', 'simulate.log']]
        hashes = {str(file.relative_to(root)): hashlib.sha256(file.read_bytes()).hexdigest()
                  for file in sources + [tb / 'pwm/pwm_axi_tb.svh', Path(__file__).resolve()]}
        (target / 'inputs.json').write_text(json.dumps({'sha256': hashes, 'commands': commands}, indent=2))
        logs = ''
        for number, command in enumerate(commands):
            result = subprocess.run(command, cwd=target, capture_output=True, text=True,
                                    errors='replace', timeout=300)
            content = result.stdout + result.stderr
            (target / f'paso_{number}.txt').write_text(content, encoding='utf-8')
            logs += content
            if result.returncode or re.search(r'(?im)^\s*(Fatal:|FATAL:|ERROR:)', content):
                raise RuntimeError(f'{top}: fallo en paso {number}; consultar {target}')
        if 'TEST PASSED' not in logs:
            raise RuntimeError(f'{top}: falta mensaje de exito')
        if top == 'tb_pwm_adc_axi':
            # XSim puede devolver 0 tras $fatal: exigir el diagnostico y ausencia de PASS.
            result = subprocess.run([binaries['xsim'], top, '-runall', '-testplusarg',
                                     'INJECT_ERROR', '-log', 'negative.log'], cwd=target,
                                    capture_output=True, text=True, errors='replace', timeout=300)
            negative = result.stdout + result.stderr
            (target / 'negative.txt').write_text(negative, encoding='utf-8')
            if 'ERROR_INYECTADO_DETECTADO' not in negative or 'TEST PASSED' in negative:
                raise RuntimeError('La prueba negativa no detecto el fallo esperado')
        results.append({'top': top, 'status': 'PASS', 'type': 'RTL_FUNCIONAL_SIN_SDF',
                        'adc': 'MODELO_DIGITAL' if top in ('tb_pwm_adc', 'tb_pwm_adc_axi') else None})
        (output / 'resumen.json').write_text(json.dumps(results, indent=2))
        print(top + ': PASS', flush=True)
    print('TODAS LAS PRUEBAS DIGITALES PASARON; no se ejecuta MicroBlaze/PR.', flush=True)


if __name__ == '__main__':
    main()
