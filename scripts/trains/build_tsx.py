# Turns a model's drawing script (scripts/trains/<model>.py, which prints the SVG painted, or unpainted with "plain")
# into its component apps/web/src/components/trains/<Model>.tsx. Lines only in the painted version are the livery and
# get wrapped in {!plain && ...}. The component's header comment is kept.
#   python3 scripts/trains/build_tsx.py x3 X3
import os, re, subprocess, sys, difflib
here = os.path.dirname(os.path.abspath(__file__))
model, comp = sys.argv[1], sys.argv[2]
gen = os.path.join(here, f'{model}.py')
target = os.path.join(here, '..', '..', 'apps', 'web', 'src', 'components', 'trains', f'{comp}.tsx')
painted = subprocess.run(['python3',gen],capture_output=True,text=True).stdout
plain = subprocess.run(['python3',gen,'plain'],capture_output=True,text=True).stdout
pl, ql = painted.splitlines(), plain.splitlines()
out=[]
for op,a0,a1,b0,b1 in difflib.SequenceMatcher(a=ql,b=pl,autojunk=False).get_opcodes():
    if op=='equal': out += [('both',l) for l in pl[b0:b1]]
    elif op=='insert': out += [('paint',l) for l in pl[b0:b1]]
    else: raise SystemExit(f'unexpected diff {op}')
vb=re.search(r'viewBox="([^"]+)"', pl[0]).group(1)
ids=sorted(set(re.findall(r'id="([a-z0-9]+)"', painted)), key=len, reverse=True)
body=[]
for kind,l in out:
    if l.startswith('<svg') or l.startswith('</svg'): continue
    l=re.sub(r'\b([a-z]+(?:-[a-z]+)+)=', lambda m: m.group(1).split('-')[0]+''.join(p.capitalize() for p in m.group(1).split('-')[1:])+'=', l)
    for i in ids: l=l.replace(f'id="{i}"','id={`${p}'+i+'`}').replace(f'"url(#{i})"','{`url(#${p}'+i+')`}')
    l=l.replace('stroke="#00000022"','stroke="#000" strokeOpacity={0.13}')
    body.append(l if kind=='both' else '{!plain && ('+l+')}')
src=open(target).read()
head=src[:src.index('return (')+len('return (')]+'\n    '
tail='''
      </g>
    </svg>
  );
}
'''
svgopen='''<svg className={className} viewBox="'''+vb+'''" role={label ? 'img' : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
      <filter id={`${p}mute`}>
        <feColorMatrix type="saturate" values="0" />
      </filter>
      <g opacity={muted ? 0.35 : 1} filter={muted ? `url(#${p}mute)` : undefined}>
'''
open(target,'w').write(head+svgopen+'\n'.join(body)+tail)
