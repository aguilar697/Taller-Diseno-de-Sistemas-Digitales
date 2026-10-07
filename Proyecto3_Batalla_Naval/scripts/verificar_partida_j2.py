"""Comprueba una partida con victoria de J2, rechazos y reinicio con marcador."""
from pathlib import Path
import json
import re
import shutil
import sys
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from vivado_common import find_bin, stage_project, invoke

output = ROOT / 'build/simulacion_j2' / datetime.now().strftime('%Y%m%d_%H%M%S_%f')
output.mkdir(parents=True)
work = stage_project()
(output / 'trabajo_adicional.txt').write_text(str(work))
bin_dir = find_bin()
packages = [work/'src/design/cpu/cpu_pkg.sv', work/'src/testbench/cpu/cpu_tb_pkg.sv']
sources = sorted((work/'src/design').rglob('*.sv')) + sorted((work/'src/testbench').rglob('*.sv'))
(work/'compilar.txt').write_text('--sv\n--work xil_defaultlib\n--define BN_FUNCTIONAL_CLOCK\n' +
    '\n'.join('"'+p.as_posix()+'"' for p in packages+[p for p in sources if p not in packages]))
invoke(bin_dir, 'xvlog', ['-f', (work/'compilar.txt').as_posix()], work, output/'adicional_compile.log')
(work/'simular.tcl').write_text('run all\nquit\n')
shutil.copy2(work/'src/software_riscv/program.hex', work/'program.hex')

def run(name):
    snapshot = name+'_extra'
    invoke(bin_dir,'xelab',['xil_defaultlib.'+name,'--snapshot',snapshot,'--mt','2'],work,output/(name+'_elab.log'))
    log = invoke(bin_dir,'xsim',[snapshot,'-tclbatch',(work/'simular.tcl').as_posix()],work,output/(name+'.log'))
    assert 'PASS' in log or 'TODAS LAS PRUEBAS PASARON' in log
    assert not re.search(r'FATAL|Fatal:|Error:|\[FAIL\]|TEST FAILED|FALLO:',log,re.I), log[-3000:]
    print('PASS',name,flush=True)

commands=[]
expected=[]
def wait(*frames):
    expected.extend(frames)
    commands.append(f'ESPERA_TRAMAS {len(expected)} 3000000')
def tx(kind,*data):
    values=[165,kind,len(data),*data]
    commands.append('TX '+str(len(values))+' '+' '.join(map(str,values)))
def button(mask):
    commands.append(f'BOTON {mask} 60000')

wait([134,0,0])
tx(17,0,0); wait([135,17,2])  # Disparo durante colocación.
tx(16,255,0,0,0); wait([128,255,0,3])
tx(16,0,0,0,2); wait([128,0,0,5])
tx(16,0,0,0,0); wait([128,0,1,0])
tx(16,0,0,0,0); wait([128,0,0,4])
tx(16,1,0,1,0); wait([128,1,0,1])
tx(16,1,2,0,0); wait([128,1,1,0])
tx(16,2,4,0,0); wait([128,2,1,0])
button(16);button(32)
button(8);button(8);button(32)
button(8);button(8);button(32)
wait([129,1],[130,1])

# J1 dispara al agua; J2 hunde los tres barcos verticales de J1.
row=col=0
hits=[(0,0),(1,0),(2,0),(3,0),(0,2),(1,2),(2,2),(0,4),(1,4)]
for index,(hr,hc) in enumerate(hits):
    target=(7,index) if index<8 else (6,7)
    while row<target[0]: button(2);row+=1
    while row>target[0]: button(1);row-=1
    while col<target[1]: button(8);col+=1
    while col>target[1]: button(4);col-=1
    button(32);wait([132,*target,0],[130,2])
    if index==0:
        tx(17,255,0);wait([135,17,5])
    if index==1:
        tx(17,0,0);wait([135,17,4])
    tx(17,hr,hc)
    result=2 if index in (3,6,8) else 1
    if index==8: wait([131,hr,hc,result],[133,2,9,9,0,3,0,1])
    else: wait([131,hr,hc,result],[130,1])
commands.extend(['ESPERA 400000','VOLCADO'])
button(64);wait([134,0,1]);commands.append('FIN')
script='\n'.join(commands)+'\n'
(work/'guion.txt').write_text(script)
(output/'guion_j2.txt').write_text(script)
(output/'tramas_j2_esperadas.txt').write_text('\n'.join(' '.join(map(str,f)) for f in expected)+'\n')
run('tb_battleship_system')
actual=[list(map(int,line.split())) for line in (work/'tramas.txt').read_text().splitlines()]
assert actual==expected,(actual,expected)
sys.path.insert(0,str(ROOT/'src/software_pc'))
from naval_terminal import Frame, valid_notification
assert all(valid_notification(Frame(f[0],bytes(f[1:]))) for f in actual)
memory={};indicators={}
for line in (work/'estado_sistema.txt').read_text().splitlines():
    f=line.split()
    if f[0]=='M': memory[int(f[1],16)]=int(f[2],16) if 'x' not in f[2].lower() else None
    elif f[0] in ('LED','DISPLAY'): indicators[f[0]]=int(f[1],16)
for player in (1,2):
    board=[0]*64
    for ship,length in enumerate((4,3,2)):
        for k in range(length):
            r,c=(k,ship*2) if player==1 else (ship*2,k)
            board[8*r+c]=3 if player==1 else 1
    if player==2:
        board[56:64]=[2]*8;board[55]=2
    for index,value in enumerate(board):
        address=(0x2000 if player==1 else 0x2100)+4*index
        assert memory[address]==value,(hex(address),memory[address],value)
for address,value in {0x2200:2,0x2204:2,0x2208:1,0x220c:1,0x2210:0,0x2214:1,
                      0x2218:9,0x221c:9,0x22f4:0,0x22f8:3,0x22fc:2}.items():
    assert memory[address]==value,(hex(address),memory[address],value)
assert indicators=={'LED':2,'DISPLAY':0x100},indicators
for name in ('tramas.txt','estado_sistema.txt','manifest.json'):
    shutil.copy2(work/name,output/('j2_'+name))
(output/'adicionales.json').write_text(json.dumps({'resultado':'PASS','tramas':len(actual),
    'palabras_ram':139,'indicadores':2,'ganador':2,'reset_conserva_marcador':True},indent=2))
print('PASS partida J2:',len(actual),'tramas, 139 palabras RAM y reinicio con marcador conservado')
