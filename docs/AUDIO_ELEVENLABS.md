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
| `i6_std_idle.wav` | 4 s | Heavy truck inline-six diesel engine idling, real semi truck, deep diesel clatter and low rumble, recorded outside near the exhaust, steady constant RPM, no acceleration, seamless loop |
| `i6_std_low.wav` | 4 s | Heavy truck inline-six diesel engine at steady low RPM pulling a heavy load, deep chugging diesel knock and rumble, real semi truck recorded from behind, no acceleration, seamless loop |
| `i6_std_mid.wav` | 4 s | Heavy truck inline-six diesel engine at steady medium RPM cruising on the highway, gritty diesel growl with mechanical clatter, real semi truck recorded from behind, no acceleration, seamless loop |
| `i6_std_high.wav` | 4 s | Heavy truck inline-six diesel engine at steady high RPM under full power, loud rough diesel roar, real semi truck recorded from behind, no acceleration, seamless loop |

### Motor 6 cilindros preparado — `i6_tuned_*.wav`

Mesmos 4 prompts trocando o começo por: *"Tuned high-performance inline-six diesel truck engine, aggressive and raspy, ..."*

### Motor V8 — `v8_*.wav`

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `v8_idle.wav` | 4 s | Monster truck racing V8 engine idling, loud choppy cammed idle, sharp crisp crackling barks from open headers, raw metallic rasp, recorded right next to the headers, steady RPM, no acceleration, seamless loop |
| `v8_low.wav` | 4 s | Monster truck racing V8 engine at steady low RPM under load, loud snarling bark with crisp crackling rasp from open headers, raw and metallic, recorded right next to the headers, no acceleration, seamless loop |
| `v8_mid.wav` | 4 s | Monster truck racing V8 engine at steady medium RPM, loud aggressive raw roar with crackling rasp through open headers, recorded close, no acceleration, seamless loop |
| `v8_high.wav` | 4 s | Monster truck racing V8 engine at steady high RPM at full throttle, ear splitting raw screaming roar with harsh crackling rasp through open headers, recorded close, no acceleration, seamless loop |

### Turbo, escape e freio-motor

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `turbo_single_whine.wav` | 3 s | Real diesel truck turbocharger at full boost recorded close under the hood, airy rushing hiss of air sucked into the compressor with a thin metallic whistle on top, mechanical industrial sound, steady, seamless loop |
| `turbo_twin_whine.wav` | 3 s | Two big diesel truck turbochargers at full boost recorded close under the hood, thick roaring rush of intake air and hiss with a faint metallic whistle, mechanical industrial sound, steady, seamless loop |
| `turbo_blowoff_1.wav` | 1 s | Big truck turbo blow-off valve release, sharp loud pssshh air burst |
| `turbo_blowoff_2.wav` | 1 s | Diesel truck turbo dump valve venting when the driver lifts off the throttle, quick sharp burst of compressed air hiss, pneumatic psssh |
| `exhaust_straight_layer.wav` | 4 s | Straight-pipe truck exhaust rumble, raw loud low frequency popping drone, steady, no acceleration, seamless loop |
| `jake_brake.wav` | 3 s | Semi truck engine brake (jake brake) loud machine-gun like braaap, steady, seamless loop |
| `engine_damaged_rattle.wav` | 3 s | Damaged diesel engine knocking and rattling, metallic clatter and misfires, steady, seamless loop |
| `engine_start.wav` | 3 s | Heavy diesel truck engine cranking and starting up, settling into idle |

### Perfis de escapamento (T-173)

Cada escapamento (exceto o padrão) tem o **próprio som do motor** em 3 camadas (marcha lenta, média e alta carga) e, com turbina,
o **próprio assobio** (loop) e o **próprio "pssh"**. O escape padrão continua usando as camadas do motor (`i6_*`/`v8_*`).
Mapa no código: `ExhaustDef.sound_profile` (`game/data/engines/exh_*.tres`) e `EngineSounds` (`game/scripts/audio/engine_sounds.gd`).

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `exh_rasp_idle.wav` | 4 s | Heavy diesel semi truck with a straight-pipe exhaust idling, raw raspy diesel crackle and rumble, recorded from behind near the tailpipe, steady constant RPM, no acceleration, seamless loop |
| `exh_rasp_mid.wav` | 4 s | Heavy diesel semi truck with a straight-pipe exhaust at steady medium RPM under load, raspy aggressive diesel snarl, recorded from behind near the tailpipe, no acceleration, seamless loop |
| `exh_rasp_high.wav` | 4 s | Heavy diesel semi truck with a straight-pipe exhaust at steady high RPM under full power, loud raw raspy diesel roar, recorded from behind near the tailpipe, no acceleration, seamless loop |
| `exh_stack_idle.wav` | 4 s | Big rig semi truck with tall vertical chrome exhaust stacks idling, deep booming diesel bass rumble, recorded outside in open air, steady constant RPM, no acceleration, seamless loop |
| `exh_stack_mid.wav` | 4 s | Big rig semi truck with tall vertical chrome exhaust stacks at steady medium RPM, deep powerful diesel thunder from the stacks, recorded outside, no acceleration, seamless loop |
| `exh_stack_high.wav` | 4 s | Big rig semi truck with tall vertical chrome exhaust stacks at steady high RPM under full power, massive deep diesel roar from the stacks, recorded outside, no acceleration, seamless loop |
| `exh_pop_idle.wav` | 4 s | Heavy diesel truck with a short cut chrome exhaust idling, rough lumpy diesel idle with occasional random pops, recorded from behind, steady constant RPM, no acceleration, seamless loop |
| `exh_pop_mid.wav` | 4 s | Heavy diesel truck with a short cut chrome exhaust at steady medium RPM, rough gritty diesel exhaust with occasional random crackles and pops, recorded from behind, no acceleration, seamless loop |
| `exh_pop_high.wav` | 4 s | Heavy diesel truck with a short cut chrome exhaust at steady high RPM, loud crackling diesel roar with random pops and bangs, recorded from behind, no acceleration, seamless loop |
| `exh_rasp_turbo_whine.wav` | 3 s | Small fast spinning turbocharger on a diesel truck at full boost recorded close, bright airy hiss with a sharp thin metallic whistle, mechanical industrial sound, steady, seamless loop |
| `exh_stack_turbo_whine.wav` | 3 s | Huge diesel big rig turbocharger at full boost recorded close, deep heavy rushing air roar like a jet intake with a low metallic whir, mechanical industrial sound, steady, seamless loop |
| `exh_pop_turbo_whine.wav` | 3 s | Diesel truck turbocharger at full boost recorded close, gritty rushing air hiss with a metallic whistle, mechanical industrial sound, steady, seamless loop |
| `exh_rasp_blowoff.wav` | 1 s | Sport turbo blow-off valve, short sharp high pitched psssh air release |
| `exh_stack_blowoff.wav` | 1 s | Huge diesel truck turbo dump valve, long deep loud whoosh of air release |
| `exh_pop_blowoff.wav` | 1 s | Diesel truck turbo blow-off valve releasing pressure, short loud pneumatic psssh of compressed air, then one dry exhaust backfire bang |

> **T-173 (2026-10-21):** os 15 sons acima e as 3 buzinas novas da seção 2 (`horn_ship_deep`, `horn_dual_tone`,
> `horn_musical_dekotora`) foram gerados com `tools/gen_audio.py` (**627 créditos**; conta em 61.873 de 131.000). Conferidos
> por análise (duração 4/3/1 s, loops estáveis; `exh_pop_high` saiu ~6 dB mais baixo e ganha +5 dB no jogo,
> `EngineSounds.LAYER_GAIN_DB`; `exh_stack_turbo_whine` saiu mais "whoosh" grave do que assobio). Marco: ouvir na
> ferramenta `scenes/tools/engine_audio_test.tscn` e pedir regeração (`python tools/gen_audio.py --only nome --force`).

> **T-178 (2026-10-21) — turbinas "de música de discoteca" refeitas; motores mais caminhão; V8 de monster truck.**
> Causa medida: os assobios da T-173 eram **notas puras** (`turbo_single_whine` = série harmônica perfeita 1141/2271/3402 Hz,
> `exh_pop_turbo_whine` com vibrato de sirene, `turbo_twin_whine` com batimento rítmico de 4 Hz) e o jogo subia o tom delas
> quase uma oitava com o boost (efeito "riser" de sintetizador). Na prévia OUVIR havia ainda um erro: antes de acelerar o
> boost valia 5,5, e a turbina tocava um guincho a ~4,6× o tom. O `turbo_blowoff_2` ("stu-tu-tu") também era tonal.
> Correção: prompts sem palavras que puxam tom ou ritmo (whine, constant pitch, siren, chirp, flutter, rhythmic, drone) e
> com ar, chiado e "mechanical industrial"; subida do tom da turbina 0,85→1,2 (`EngineAudio.turbo_pitch_for`); boost da
> prévia preso em 0..1 (`SoundPreview.boost_at`). Refeitos 28 sons (5 assobios, 2 pssh, 8 do 6 cilindros, 4 do V8, 9 dos
> perfis de escape), com `prompt_influence` 0,7 e 2 a 3 versões de cada, escolhidas por análise (planicidade espectral,
> pulsação, emenda do loop): **3.179 créditos** (conta em 65.052 de 131.000).
> Os sons de antes estão em `audio_backup/t178_antes/`. Todas as versões geradas estão em `audio_backup/t178_variantes*/`, e a
> escolhida de cada som está em `audio_backup/t178_escolhas.txt`: para trocar por outra versão, basta copiar, sem gastar créditos.
> Prévias OUVIR em WAV, antes e depois: `audio_backup/t178_previas_ouvir/`. Ferramentas (rodam no Blender): `tools/audio_analyze.py`,
> `tools/audio_spectro.py` e `tools/audio_preview_mix.py`. Novo no `gen_audio.py`: `--out-dir PASTA --variants N --influence 0.7`.
> Atenção: a marcha lenta do V8 tende a sair muito grave (mais de 80% abaixo de 150 Hz em 8 tentativas). Foi escolhida a com
> mais estalos, mas no alto-falante do celular ela soa mais baixa.

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
| `horn_ship_deep.wav` | 3 s | Extremely deep and loud air horn of a huge truck sounding like a ship foghorn, single long sustained low blast, steady |
| `horn_dual_tone.wav` | 3 s | Two-tone truck air horn with a high trumpet and a low trumpet sounding together, long sustained loud blast, steady |
| `horn_musical_dekotora.wav` | 3 s | Japanese dekotora truck musical air horn playing a fast festive melody of eight rising and falling notes, loud bright trumpets |
| `passing_flash.wav` | 0,5 s | Quick electric click and whoosh of high beam headlights flashing |
| `cargo_rattle_loop.wav` | 3 s | Loose cargo shaking and rattling inside a metal truck box, steady, seamless loop |
| `steel_plate_clank.wav` | 0,5 s | Heavy truck tire rolling fast over a loose steel road plate at road works, loud metallic clank and bang |
| `turn_signal_tick.wav` | 0,5 s | Single click of a truck turn signal flasher relay heard inside the cab, one short dry plastic tick at the very start, isolated, no reverb, silence after the click |
| `turn_signal_switch.wav` | 0,5 s | Truck turn signal stalk lever flicked on the steering column, one short crisp plastic snap click at the very start, isolated, no reverb, silence after |

> **T-170 (seta / pisca):** `turn_signal_tick` toca a cada vez que a lâmpada da seta acende (tom normal) e apaga (tom
> mais grave), sincronizado com o pisca (`SignalBlink`, 1,5 Hz); `turn_signal_switch` é o clique da alavanca a cada
> toque em < ou > (liga a seta, troca de faixa ou troca recusada). Ficam na seção 2 (caminhão), não na 4 (ambiente).

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
| `cone_hit.wav` | 1 s | Big truck knocking over a plastic traffic cone, hollow plastic thump and clatter on asphalt |
| `barrier_scrape.wav` | 1 s | Truck side scraping along plastic road barriers at a lane closure, short rough plastic scrape |
| `truck_body_slam.wav` | 1,5 s | Two heavy steel trucks slamming into each other, deep low boom with crunching metal body panels, short |
| `truck_side_bang.wav` | 1 s | Two big trucks banging side to side at highway speed, heavy hollow metal clang followed by a short scraping screech |
| `chrome_debris_scatter.wav` | 1,5 s | Small chrome metal pieces and plastic light fragments scattering and bouncing on asphalt after a crash |
| `car_tumble.wav` | 1,5 s | Small car flipping and tumbling on a highway after being hit by a big truck, thin metal crunching and glass cracking |

> **T-141 (2026-10-19):** `truck_body_slam`, `truck_side_bang`, `chrome_debris_scatter` e `car_tumble` foram gerados com
> `tools/gen_audio.py` (~100–250 créditos; conta em 60.935 de 131.000 depois). Marco: ouvir e pedir regeração se algum ficar ruim
> (`python tools/gen_audio.py --only nome --force`). Freio (`brake_squeal`, `air_brake_hiss`) e buzinas já existiam.
> `tools/gen_audio.py` agora acha a `.chaves.env` também quando roda numa worktree (procura nas pastas acima).

## 4. Ambiente (`game/assets/audio/sfx/ambient/`)

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `wind_speed_loop.wav` | 5 s | Strong wind rushing past a fast moving truck cabin on a highway, steady, seamless loop |
| `highway_night_loop.wav` | 8 s | Distant Japanese highway at night, faint passing cars, calm ambience, seamless loop |
| `toll_gate.wav` | 2 s | Japanese highway toll gate electronic beep and barrier lifting |
| `pass_car_whoosh.wav` | 1,5 s | Car passing very close at high speed, doppler whoosh |
| `roadworks_loop.wav` | 5 s | Highway road works at night, diesel generator hum, distant jackhammer, faint warning beeps, seamless loop |
| `train_horn.wav` | 3 s | Deep low-pitched freight train horn, single long blast, no music, no melody, isolated |
| `train_pass.wav` | 6 s | Freight train passing at speed, steel wheels rolling over rail joints with rhythmic clack-clack, steady, no music, seamless loop |

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
| `event_alert_chime.wav` | 1 s | Japanese highway information board alert chime, clear two-tone electronic ding dong |
| `vs_taiko_hit.wav` | 1,5 s | Single powerful Japanese taiko drum hit with a deep boom and a short reverb tail, dramatic showdown intro stinger, no music |

> **T-139 (eventos de pista):** `cone_hit`, `barrier_scrape`, `steel_plate_clank`, `event_alert_chime` e `roadworks_loop` ainda
> **não foram gerados**. Enquanto não existem, o jogo toca sons de reserva (batida leve / bip da contagem) e o ruído das obras fica
> mudo. Para gerar: `python tools/gen_audio.py --only cone_hit,barrier_scrape,steel_plate_clank,event_alert_chime,roadworks_loop`
> e ouvir antes de aceitar.

> **T-168 (ferrovia):** `train_horn` (buzina grave de trem de carga, 3 s) e `train_pass` (passagem com rodas e juntas
> dos trilhos, 6 s, gerado com a opção de loop do ElevenLabs) foram gerados com `tools/gen_audio.py` em `sfx/ambient/`.
> **Ainda não ligados ao jogo** (tarefa separada). Marco: ouvir e pedir regeração se algum ficar ruim (`--only nome --force`).

> **T-156 (abertura frente a frente):** `vs_taiko_hit` (tambor no banner VS) foi gerado com `tools/gen_audio.py`
> (conta em ~61.100 de 131.000 créditos). Os outros sons da cena já existiam: motor acelerando parado = as camadas
> do motor (`i6_*`/`v8_*`) com o giro subindo e descendo; buzina de provocação do rival = `horn_musical_1` (ou a
> buzina musical das peças dele). Marco: ouvir e pedir regeração se quiser (`python tools/gen_audio.py --only vs_taiko_hit --force`).

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

## Chave da API
A chave fica em `.chaves.env` (raiz do projeto, fora do git) na variavel `ELEVENLABS_API_KEY`. Nunca escreva o valor em docs ou commits.

## 8. Ambiente por bioma e chuva — T-189 (`game/assets/audio/sfx/ambient/`)

Ainda **faltam** (o jogo funciona sem eles: o som é pulado; a cidade usa `highway_night_loop` até chegar o dela).
Todos são loops: gere 20–30 s, sem começo/fim marcado, volume constante. O nome precisa terminar em `_loop`.
Use "Sound Effects" do ElevenLabs, duração máxima, "Prompt influence" alto.

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `amb_cicadas_day_loop.mp3` | 25 s | Loopable ambience of Japanese summer cicadas (minminzemi and aburazemi) in a mountain forest, steady dense chorus, distant, no wind, no voices, no music |
| `amb_sea_waves_loop.mp3` | 25 s | Loopable ambience of gentle ocean waves on a sandy beach heard from a coastal highway, soft surf and wash, distant seagulls very faint, no voices, no music |
| `amb_city_day_loop.mp3` | 25 s | Loopable daytime Japanese city ambience heard from an elevated expressway, distant traffic hum, faint crosswalk chime, far construction, no clear voices, no music |
| `amb_city_night_loop.mp3` | 25 s | Loopable night Japanese city ambience under an elevated expressway, low traffic hum, distant train, faint neon buzz, no clear voices, no music |
| `amb_night_frogs_crickets_loop.mp3` | 25 s | Loopable summer night ambience in Japanese rice fields, frogs croaking and crickets chirping, calm, distant, no wind, no voices, no music |
| `amb_birds_day_loop.mp3` | 25 s | Loopable daytime countryside ambience, small birds chirping in trees, occasional distant crow, calm, no wind, no voices, no music |
| `amb_rain_loop.mp3` | 25 s | Loopable steady medium rain on asphalt and on a truck roof, close and wide, light splashes, no thunder, no music |

Já existem e passaram a tocar (T-189): `train_horn.mp3` (buzina distante quando um trem entra no alcance) e
`train_pass.mp3` (passagem perto), ambos posicionais.

## 9. Motor diesel sintetizado, bonde e freio a ar — T-197 (não precisa do ElevenLabs)

O som dos caminhões e do bonde agora é **gerado por código** (`python tools/synth_truck_audio.py`, só numpy, sempre
igual). Nada para gerar no ElevenLabs: tudo já está no jogo. Os arquivos ficam ao lado dos antigos, em `.wav`:

| Arquivo(s) | O que é |
| --- | --- |
| `engines/syn_<voz>_on_<rpm>.wav` / `_off_<rpm>` | motor acelerando / sem acelerar (a 700 rpm o "off" é a marcha lenta). Vozes: `i6` (6 cil. padrão), `i6t` (preparado), `v8`, `i4` (Canter). RPM: 700, 1000, 1400, 1900, 2500 |
| `engines/syn_<voz>_jake_<rpm>.wav` | freio-motor (jake brake) em 1300, 1800, 2400 rpm |
| `engines/syn_<voz>_open_<rpm>.wav` | ronco rasgado de escape aberto (reto, chaminés, cromado) em 1000, 1600, 2300 rpm |
| `engines/syn_exh_pop_1/2.wav` | estalos do cromado cortado ao tirar o pé |
| `sfx/truck/gear_air_pfft.wav`, `air_brake_park.wav`, `tyre_road_loop.wav` | "pfft" do câmbio a ar, "tssss" ao parar, rodagem dos pneus |
| `sfx/ambient/tram_bell.wav`, `tram_run_loop.wav` | sino "chin-chin" do bonde e o rodar leve dele (zumbido elétrico, trilho, rangido) |

- O jogo usa o **mp3 primeiro** se existir um com o mesmo nome. Então, se o Marco quiser trocar um destes por um do
  ElevenLabs, basta gerar com o nome abaixo: o `.wav` sintetizado fica só como reserva.
- Som antigo para comparar: `-- --engine-sound=old` na linha de comando, ou "Som antigo" na cena de teste.

**Opcional** (só se o sintetizado não agradar; gere 2–3 versões e escolha):

| Arquivo | Duração | Prompt |
| --- | --- | --- |
| `tram_bell.mp3` | 2 s | Japanese streetcar bell, two quick light metallic dings "chin chin" from a small bell on a tram, close, dry, no music, no voices |
| `tram_run_loop.mp3` | 20 s | Loopable sound of a modern light rail tram running at steady medium speed heard from the roadside, soft electric motor hum, light steel wheels on rails, occasional rail joint clicks, faint flange squeal, no horn, no bell, no voices, no music |
| `air_brake_park.mp3` | 1 s | Heavy truck parking air brake release, short sharp pneumatic hiss "pssht" when the truck stops, close, no engine, no music |
| `tyre_road_loop.mp3` | 20 s | Loopable heavy truck tyre roll noise on dry asphalt at highway speed, steady low road roar, no engine, no wind gusts, no music |

Não recomendo voltar a gerar **motores** no ElevenLabs: o gerador não segura um giro fixo (o tom e o ritmo mudam
dentro do arquivo), e o jogo precisa de loops em RPM exato para a troca de marcha e o freio-motor soarem certos.
