# Áudio — prompts do ElevenLabs

Marco gera cada som no ElevenLabs e salva **com o nome exato** na pasta indicada.
Prompts em inglês (o modelo responde melhor). Gere 2 a 4 variações de cada e escolha a melhor.

## Como gerar

- **Efeitos e motores**: ElevenLabs → *Sound Effects*. Cole o prompt, ajuste a duração indicada.
  Para loops, ligue a opção de **loop** se estiver disponível; se não, gere e o Claude corta o ponto de loop.
- **Música**: ElevenLabs → *Music*. Marque instrumental quando houver a opção.
- Formatos: efeitos em **WAV**, música em **MP3 ou WAV** (o Claude converte para OGG).
- Licença: plano gratuito serve para testes (uso não comercial, exige crédito). Para publicar, gerar de novo num plano pago.

## 1. Motores (`game/assets/audio/engines/`)

Cada motor tem 4 loops em rotação **constante** (sem acelerar no meio), para o jogo misturar por RPM.
Dica: sempre inclua "steady constant RPM, no acceleration, seamless loop".

### Motor 6 cilindros padrão — `i6_std_*.wav`

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `i6_std_idle.wav` | 4 s | Heavy Japanese truck inline-six diesel engine idling, steady constant RPM, low rumble, recorded from behind the truck, no acceleration, seamless loop |
| `i6_std_low.wav` | 4 s | Heavy truck inline-six diesel engine at steady low RPM under load, deep chugging, recorded from behind, no acceleration, seamless loop |
| `i6_std_mid.wav` | 4 s | Heavy truck inline-six diesel engine at steady medium RPM cruising on highway, strong drone, recorded from behind, no acceleration, seamless loop |
| `i6_std_high.wav` | 4 s | Heavy truck inline-six diesel engine at steady high RPM near redline, loud straining roar, recorded from behind, no acceleration, seamless loop |

### Motor 6 cilindros preparado — `i6_tuned_*.wav`

Mesmos 4 prompts trocando o começo por: *"Tuned high-performance inline-six diesel truck engine, aggressive and raspy, ..."*

### Motor V8 — `v8_*.wav`

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `v8_idle.wav` | 4 s | Huge V8 diesel truck engine idling with a lopey uneven burble, deep bass, steady RPM, no acceleration, seamless loop |
| `v8_low.wav` | 4 s | Huge V8 diesel truck engine at steady low RPM under heavy load, thunderous rumble, no acceleration, seamless loop |
| `v8_mid.wav` | 4 s | Huge V8 diesel truck engine cruising at steady medium RPM, powerful growl, no acceleration, seamless loop |
| `v8_high.wav` | 4 s | Huge V8 diesel truck engine at steady high RPM, screaming heavy roar, no acceleration, seamless loop |

### Turbo, escape e freio-motor

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `turbo_single_whine.wav` | 3 s | Diesel truck turbocharger whistle at steady high boost, constant pitch high whine, isolated, no engine, seamless loop |
| `turbo_twin_whine.wav` | 3 s | Twin turbochargers whistling together at steady boost, layered high pitched whine, isolated, no engine, seamless loop |
| `turbo_blowoff_1.wav` | 1 s | Big truck turbo blow-off valve release, sharp loud pssshh air burst |
| `turbo_blowoff_2.wav` | 1 s | Truck turbo wastegate flutter, rapid chattering stu-tu-tu air sound when lifting off throttle |
| `exhaust_straight_layer.wav` | 4 s | Straight-pipe truck exhaust rumble, raw loud low frequency popping drone, steady, no acceleration, seamless loop |
| `jake_brake.wav` | 3 s | Semi truck engine brake (jake brake) loud machine-gun like braaap, steady, seamless loop |
| `engine_damaged_rattle.wav` | 3 s | Damaged diesel engine knocking and rattling, metallic clatter and misfires, steady, seamless loop |
| `engine_start.wav` | 3 s | Heavy diesel truck engine cranking and starting up, settling into idle |

## 2. Caminhão (`game/assets/audio/sfx/truck/`)

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `gear_shift_1.wav` | 1 s | Heavy truck gearbox shift clunk with short air hiss |
| `gear_shift_2.wav` | 1 s | Truck transmission gear change, mechanical thunk, quick |
| `air_brake_hiss.wav` | 1,5 s | Truck air brake release, loud sharp pneumatic hiss |
| `brake_squeal.wav` | 2 s | Heavy truck brakes squealing while slowing down |
| `tire_screech_loop.wav` | 3 s | Large truck tires screeching on asphalt in a hard turn, steady, seamless loop |
| `tire_gravel_loop.wav` | 3 s | Big truck tires rolling over gravel shoulder, crunching rumble, seamless loop |
| `horn_air_basic.wav` | 2 s | Loud deep truck air horn single blast |
| `horn_musical_1.wav` | 3 s | Japanese decorated truck musical air horn playing a short cheerful melody of five notes |
| `horn_musical_2.wav` | 3 s | Multi-tone train-style air horn chord on a big truck, dramatic |
| `passing_flash.wav` | 0,5 s | Quick electric click and whoosh of high beam headlights flashing |
| `cargo_rattle_loop.wav` | 3 s | Loose cargo shaking and rattling inside a metal truck box, steady, seamless loop |

## 3. Batidas (`game/assets/audio/sfx/crash/`)

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `bump_light_1.wav` | 1 s | Light metal bump between two heavy trucks, dull thud |
| `bump_light_2.wav` | 1 s | Two trucks lightly touching side to side, metal knock |
| `crash_heavy_1.wav` | 2 s | Violent heavy truck collision, loud crunching metal impact |
| `crash_heavy_2.wav` | 2 s | Huge truck slamming into another truck from behind, deep boom and metal crunch |
| `scrape_loop.wav` | 3 s | Metal scraping against metal as two trucks grind side by side, sparks, seamless loop |
| `chrome_part_break.wav` | 1,5 s | Chrome bumper ripping off a truck and clattering on asphalt |
| `lights_shatter.wav` | 1 s | Many small light bulbs and plastic covers shattering |
| `glass_break.wav` | 1 s | Truck side window glass breaking |
| `guardrail_hit.wav` | 1,5 s | Truck hitting a highway steel guardrail, loud clang and scrape |
| `car_hit.wav` | 1 s | Big truck hitting a small car, crunch of thin metal |

## 4. Ambiente (`game/assets/audio/sfx/ambient/`)

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `wind_speed_loop.wav` | 5 s | Strong wind rushing past a fast moving truck cabin on a highway, steady, seamless loop |
| `highway_night_loop.wav` | 8 s | Distant Japanese highway at night, faint passing cars, calm ambience, seamless loop |
| `toll_gate.wav` | 2 s | Japanese highway toll gate electronic beep and barrier lifting |
| `pass_car_whoosh.wav` | 1,5 s | Car passing very close at high speed, doppler whoosh |

## 5. Interface (`game/assets/audio/sfx/ui/`)

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `ui_select.wav` | 0,3 s | Retro arcade menu select blip, short and bright |
| `ui_back.wav` | 0,3 s | Retro arcade menu back sound, short descending blip |
| `ui_buy.wav` | 1 s | Cash register cha-ching, retro game style |
| `ui_repair.wav` | 1,5 s | Mechanic wrench ratchet clicking quickly, then a metal clank |
| `ui_error.wav` | 0,5 s | Short low buzzer error sound, retro game |
| `countdown_beep.wav` | 0,5 s | Racing countdown beep, single tone |
| `countdown_go.wav` | 1 s | Racing start signal, higher long beep with excitement |
| `win_fanfare.wav` | 4 s | Short triumphant retro arcade victory fanfare with synths |
| `lose_jingle.wav` | 3 s | Short sad retro arcade game over jingle |
| `fame_up.wav` | 1 s | Sparkly shimmering chime, reward pickup |

## 6. Multiplayer (`game/assets/audio/sfx/net/`)

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `player_join.wav` | 1 s | Friendly two-note chime, someone joined the lobby |
| `player_leave.wav` | 1 s | Soft descending two-note chime |
| `all_ready.wav` | 1,5 s | Energetic rising synth stinger, everyone ready |

## 7. Música (`game/assets/audio/music/`)

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `menu_citypop.mp3` | 2 min | Instrumental 1980s Japanese city pop, funky slap bass, bright synth pads, electric piano, groovy drums, nostalgic night drive mood, loopable |
| `garage_chill.mp3` | 2 min | Instrumental relaxed Japanese city pop lo-fi, mellow electric piano, soft funk bass, warm late night garage mood, loopable |
| `race_night_synthwave.mp3` | 2 min 30 s | Instrumental fast synthwave, 140 BPM, driving arpeggios, punchy drums, neon highway at night, high energy, loopable |
| `race_day_rock.mp3` | 2 min 30 s | Instrumental upbeat Japanese arcade racing rock, 150 BPM, distorted guitar riffs, synth lead, energetic drums, loopable |
| `boss_enka_rock.mp3` | 2 min 30 s | Instrumental dramatic rock fused with Japanese enka melody, shamisen-like lead, heavy guitars and drums, rival showdown, loopable |
| `lobby_wait.mp3` | 1 min 30 s | Instrumental chill funky waiting music, light synth and bass groove, 100 BPM, loopable |
| `results_win.mp3` | 10 s | Short instrumental victory jingle, city pop style, bright brass synths |
| `results_lose.mp3` | 8 s | Short instrumental melancholic city pop jingle, slow electric piano |

## Checklist de entrega

- [ ] Nomes exatamente como na tabela
- [ ] Pastas certas
- [ ] Avisar o Claude: "Áudio da seção X salvo". Ele confere duração, volume e cria os loops.
