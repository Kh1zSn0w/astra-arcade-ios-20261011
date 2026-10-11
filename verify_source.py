from pathlib import Path
import struct, wave

root=Path(__file__).resolve().parent
scene=(root/'Astra'/'AstraScene.swift').read_text()
app=(root/'Astra'/'AstraApp.swift').read_text()
required=['beginMission','updateHostiles','updateProjectiles','spawnFormation','summonBoss','useBomb','updateSupplies','showGameOver','displayPause','touchesMoved']
assert all(name in scene for name in required), 'Required gameplay system missing'
assert 'SpriteKit' in app and 'AVFoundation' in app
assert 'io.github.kh1zsn0w.astraarcade' in (root/'project.yml').read_text()
assets=root/'Astra'/'Assets'
for name in ['falcon','enemy_scout','enemy_ace','enemy_heavy','boss','laser','enemy_laser','boss_laser','pickup_power','pickup_repair','pickup_bomb','pickup_shield']:
    p=assets/(name+'.png')
    assert p.exists() and p.read_bytes()[:8]==bytes.fromhex('89504e470d0a1a0a'), name
for name in ['shoot','hit','explode','pickup','click','bomb','warning','music']:
    with wave.open(str(assets/(name+'.wav')),'rb') as wav:
        assert wav.getnframes()>1000 and wav.getframerate()==22050, name
icon=root/'Astra'/'Assets.xcassets'/'AppIcon.appiconset'/'astra_icon.png'
img=icon.read_bytes()
assert img[:8]==bytes.fromhex('89504e470d0a1a0a')
assert struct.unpack('>II',img[16:24])==(1024,1024)
print('SOURCE_VERIFIED: 12 original sprite assets, 8 synthesized sound assets, 1024px icon, gameplay controls and bundle ID')
