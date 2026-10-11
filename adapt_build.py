from pathlib import Path
source=Path.home()/'Documents'/'WeatherGlass'/'manage_build.py'
root=Path(__file__).resolve().parent
old=source.read_text(encoding='utf-8')
mapping={
    'Kh1zSn0w/atmos-weather-iphone-20261011':'Kh1zSn0w/astra-arcade-ios-20261011',
    'Atmos native SwiftUI iPhone weather app, source only':'Astra original SpriteKit vertical arcade shooter, source only',
    'Build standalone Atmos native iOS weather app':'Build original Astra retro plane shooter',
    'Atmos-iPhone-v1.0':'Astra-Retro-Sky-iOS-v1.0',
    'Atmos-Weather-v1.0-unsigned.ipa':'Astra-Retro-Sky-v1.0-unsigned.ipa',
    'Atmos-Weather-v1.0-':'Astra-Retro-Sky-v1.0-',
    'Payload/WeatherGlass.app/':'Payload/Astra.app/',
    'Payload/WeatherGlass.app/WeatherGlass':'Payload/Astra.app/Astra',
    'io.github.kh1zsn0w.atmosweather':'io.github.kh1zsn0w.astraarcade'
}
for a,b in mapping.items():
    if a not in old:
        print('WARNING missing', a)
    old=old.replace(a,b)
(root/'manage_build.py').write_text(old, encoding='utf-8')
print('ADAPTED',len(old),'characters')
