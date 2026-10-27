# JHenTai + nomacs — progresso e handoff

Data: 2026-10-26
Máquina: Windows, usuário `Duzk`

## 1. Estado atual

- Fork: `https://github.com/Darkiu1337/JHenTai`
- Branch de trabalho: `nomacs-stream`
- Clone local: `C:\Users\Duzk\Desktop\JHenTai-nomacs`
- Workflow de build: `.github/workflows/build-windows-nomacs.yml`
- Artifact: `JHenTai-Windows-nomacs` (zip)
- Build instalada: `C:\Users\Duzk\Desktop\JHenTai_8.0.18+344_nomacs`
- Atalho: `C:\Users\Duzk\Desktop\JHenTai (nomacs).lnk`
- Instalação antiga preservada: `C:\Users\Duzk\Desktop\JHenTai_8.0.18+341`
- Dados do app: `%APPDATA%\top.jtmonster\jhentai` (`db.sqlite`, schema 25)
- Backups do banco: `%APPDATA%\top.jtmonster\jhentai\db.sqlite.bak-nomacs-*`
- nomacs: `C:\Program Files\nomacs\bin\nomacs.exe` (versão 3.22.4)

## 2. O que já foi implementado

### 2.1 Abrir a galeria online no nomacs

Gatilho atual: **somente botão direito → “Abrir no nomacs”**. O duplo clique foi removido
e o delay de 300 ms no toque simples também foi removido.

Fluxo:

1. O app cria `%TEMP%\jhentai_nomacs\<gid>_<token>_<timestamp>\`.
2. Grava a página atual como `00001.jpg` (ou `.png`, `.webp` etc.).
3. Abre `nomacs.exe --private <arquivo>` com `workingDirectory` na pasta `bin` do nomacs.
4. Baixa o resto da galeria **sequencialmente**, uma página por vez:
   - primeiro `N+1`, `N+2`, ... até o fim;
   - depois `N-1`, `N-2`, ... até o começo.
5. O nomacs tem `QFileSystemWatcher` na pasta e adiciona as páginas novas sozinho
   (`DkImageLoader::directoryChanged`), então dá para ir passando com ←/→.
6. Ao fechar o nomacs, o download é cancelado e a pasta temporária é apagada.

Arquivos principais:

- `lib/src/service/nomacs_stream_service.dart` — serviço de streaming, fila sequencial,
  escrita atômica (`.part` → rename), detecção de HTML de limite de imagem, limpeza.
- `lib/src/pages/read/layout/base/base_layout_logic.dart` — `openInNomacs(index)` e itens
  de menu (online, baixado e arquivo).
- `lib/src/pages/read/read_page_logic.dart` — `resolveImageForNomacs(index)` (parseia a URL
  da página sob demanda, sem mexer no estado do leitor para todas as páginas).
- `lib/src/l18n/en_US.dart` e `pt_BR.dart` — textos `openInNomacs`, `nomacsPreparing` etc.

Detalhes importantes do nomacs 3.22.4:

- **Não existe `--new-instance`** (isso é de uma versão mais nova do nomacs). O app usa
  apenas `--private`.
- Se já existe uma instância do nomacs aberta, o processo novo **encaminha o arquivo e
  sai na hora**. Por isso a limpeza não depende só do `exitCode`: quando o processo sai em
  menos de 2 s, o serviço espera todos os `nomacs.exe` fecharem (`tasklist`) antes de
  apagar a pasta.
- Se o JHenTai fechar antes do nomacs, a pasta fica; `_cleanStale()` remove pastas com
  mais de 24 h na próxima abertura.
- A URL `s.exhentai.org` é normalizada para `ehgt.org` (mesma regra do `EHImage`) para
  reaproveitar o cache do `extended_image` em `%TEMP%\cacheimage`.

### 2.2 Login por cookies (contorno do Cloudflare)

A tela de login estava bloqueada pelo Cloudflare. Em vez de usar a tela:

- `local_config.eh_cookies` foi preenchido com os cookies de sessão
  (`ipb_member_id`, `ipb_pass_hash`, `igneous`, `sk`, `yay`).
- `local_config.userSetting` foi preenchido com `ipbMemberId=5957757` e o `ipbPassHash`,
  para `userSetting.hasLoggedIn()` retornar `true`.
- Verificado: favoritos e site settings autenticados carregam no log, e a página de
  favoritos do ExHentai retorna a lista real.
- O nome exibido ficou `Darkiu1337` (placeholder; o fórum estava bloqueado pelo
  Cloudflare). É cosmético; pode ser trocado em Configurações → Conta.

**Não colocar cookies neste documento nem no repositório.** Eles ficam apenas no
`db.sqlite` local. Se a sessão expirar, é preciso pegar cookies novos no navegador e
repetir o processo.

## 3. Como rebuildar

O build é feito no GitHub Actions, sem Flutter/Visual Studio local.

```powershell
# gh não está no PATH; use o caminho completo ou prefixe:
$env:Path="C:\Program Files\GitHub CLI;$env:Path"

cd C:\Users\Duzk\Desktop\JHenTai-nomacs
# editar o código
git add -A
git commit -m "descrição"
git push
```

O push na branch `nomacs-stream` dispara o workflow. Para acompanhar e baixar:

```powershell
gh run list -R Darkiu1337/JHenTai --branch nomacs-stream --limit 3
gh run watch <RUN_ID> -R Darkiu1337/JHenTai --exit-status
gh run download <RUN_ID> -R Darkiu1337/JHenTai -n JHenTai-Windows-nomacs -D <pasta>
```

O zip contém uma pasta `JHenTai_8.0.18+344`; ela é extraída e o conteúdo é movido para
a pasta de instalação. O banco e as configurações ficam no `%APPDATA%`, então trocar a
pasta do executável não perde nada.

Configuração do workflow:

- `windows-2022`
- Flutter `3.44.8`, channel `master`
- `flutter build windows -t lib/src/main.dart --release`
- Empacota `build\windows\x64\runner\Release` + DLLs de `windows\`
- Não usa secrets: `lib/src/config/jh_api_secret_config.dart` é placeholder vazio.

## 4. Próximas features pedidas pelo usuário

### 4.1 Manter o zoom ao passar de imagem

O zoom é feito com o fork `jiangtian616/photo_view` (ref `1fecde37` no `pubspec.yaml`).

- Modo página: `lib/src/pages/read/layout/horizontal_page/horizontal_page_layout.dart`
  e `lib/src/pages/read/layout/horizontal_double_column/horizontal_double_column_layout.dart`.
  Hoje cada página usa `PhotoViewGalleryPageOptions.customChild` **sem** `controller`,
  então cada página tem seu próprio estado de zoom. Para manter o zoom, será preciso
  compartilhar `PhotoViewController` / `PhotoViewScaleStateController` (ou capturar
  `scale`/`position` antes da troca e reaplicar na página nova).
- Modo lista: `vertical_list_layout.dart` e `horizontal_list_layout.dart` usam **um**
  `PhotoViewGallery` em volta da lista inteira, com
  `state.photoViewController` (`VerticalListLayoutState` / `HorizontalListLayoutState`).
  Nesses modos o zoom já é global; “manter” significa preservar a escala/posição ao
  trocar de imagem.
- `BaseLayoutLogic.scaleStateCycle` (`base_layout_logic.dart`) controla o ciclo do
  duplo clique para zoom; a configuração é `readSetting.enableDoubleTapToScaleUp`.
- Cuidado: `PhotoViewGallery` também tem seu próprio controller interno por página;
  verifique a API do fork antes de compartilhar um controller entre páginas.

### 4.2 Ir para o topo automaticamente ao passar de imagem, mantendo o zoom

- Modo página: o listener de troca está em
  `horizontal_page_layout_logic.dart` (`_readProgressListener`) e em
  `horizontal_double_column_layout_logic.dart` (`pageController.addListener`).
  Após a troca, resetar a posição vertical do `PhotoViewController` para o topo
  (`updatePosition`/`updateMultiple`) sem mudar a escala.
- Modo lista: o scroll é `ScrollablePositionedList` com
  `state.scrollOffsetController` / `state.itemScrollController` em
  `vertical_list_layout_logic.dart` / `horizontal_list_layout_logic.dart`.
  “Topo” no modo vertical = início do item novo; no horizontal, decidir se é topo
  vertical ou início horizontal.
- As configurações de direção de leitura e layout estão em
  `lib/src/setting/read_setting.dart` e nos `*_layout_logic.dart`.

### 4.3 Shader Anime4K Restore L

Hoje o app **não tem pipeline de shader** para exibição de imagem. O que existe é
super-resolução via Real-ESRGAN:

- `lib/src/service/super_resolution_service.dart`
- `realesrgan-ncnn-vulkan.exe` em `%APPDATA%\top.jtmonster\jhentai\realesrgan`
- configurado em `lib/src/setting/super_resolution_setting.dart`

Anime4K Restore L é um shader GLSL (mpv). Para implementar no Flutter:

- Pesquisar `FragmentProgram` / `FragmentShader`, `ShaderMask`, `ImageFilter.shader` e
  `ui.Image` + `Paint.shader` no Impeller (Windows). O Flutter 3.44 já suporta shaders
  de fragmento; é preciso adicionar a seção `flutter: shaders:` no `pubspec.yaml` e
  portar o GLSL do Anime4K para a linguagem de shader do Flutter.
- Anime4K Restore L normalmente é uma cadeia de passes (não um único shader). Pode ser
  necessário aplicar em uma imagem decodificada (`ui.Image`) e cachear o resultado, não
  a cada frame.
- Alternativa mais simples: rodar o Anime4K como pré-processamento (CPU/GPU externa)
  semelhante ao Real-ESRGAN e exibir a imagem processada.
- O(app) tem `assets/` e `data/flutter_assets/shaders/` com shaders internos do Flutter;
  não há shader customizado hoje.
- Performance e qualidade: medir em imagens grandes; evitar aplicar em toda a galeria
  de uma vez.

### 4.4 Setas para mover a imagem verticalmente quando está com zoom

- Os atalhos de teclado estão em `lib/src/pages/read/read_page.dart`:
  `EHKeyboardListener` + `keyboardShortcutSetting.buildHandlerMap(...)`.
- `lib/src/setting/keyboard_shortcut_setting.dart` mapeia
  `LogicalKeyboardKey.arrowUp/arrowDown/arrowLeft/arrowRight`.
- Para pan vertical com zoom:
  - detectar `PhotoViewController.scale > 1.0` (ou o estado equivalente do layout);
  - interceptar `arrowUp`/`arrowDown` antes do mapa de páginas e chamar
    `updatePosition`/`updateMultiple` no controller ativo;
  - no modo lista, o controller é `state.photoViewController`; no modo página, será
    preciso expor/compartilhar o controller (ver 4.1).
- Também vale considerar o wheel do mouse com Ctrl/Shift para pan, e manter ←/→ para
  troca de página quando não estiver com zoom.

## 5. Armadilhas conhecidas

- nomacs 3.22.4: só `--private`; não usar `--new-instance`.
- O download é sequencial de propósito. Se uma página falhar, o stream para para não
  criar buraco na numeração. O usuário pode reabrir a partir da página desejada.
- Limite de imagens do e-hentai: pode retornar HTML com HTTP 200; o serviço detecta
  (`<html`/`<!doctype`), limpa o cache da URL e para.
- Não apagar `%TEMP%\cacheimage` inteiro: é o cache normal do leitor.
- O app e o nomacs podem ficar abertos ao mesmo tempo; a pasta temp só é apagada quando
  todos os `nomacs.exe` fecham.
- O build é não assinado; SmartScreen/Defender podem reclamar.
- O `gh` CLI está em `C:\Program Files\GitHub CLI\gh.exe` e não está no PATH desta
  sessão; prefixe o PATH nos comandos.
- O repositório usa dependências Git; o workflow já roda `git config --global
  core.longpaths true`.

## 6. Mapa rápido de arquivos

| Assunto | Arquivo |
|---|---|
| Streaming nomacs | `lib/src/service/nomacs_stream_service.dart` |
| Menu do nomacs | `lib/src/pages/read/layout/base/base_layout_logic.dart` |
| Parse de URL para o stream | `lib/src/pages/read/read_page_logic.dart` |
| Gestos/tap zones | `lib/src/pages/read/read_page.dart` |
| Layout página | `lib/src/pages/read/layout/horizontal_page/` |
| Layout lista vertical | `lib/src/pages/read/layout/vertical_list/` |
| Layout lista horizontal | `lib/src/pages/read/layout/horizontal_list/` |
| Layout duas colunas | `lib/src/pages/read/layout/horizontal_double_column/` |
| Zoom (photo_view) | `pubspec.yaml` + layouts acima |
| Super-resolução atual | `lib/src/service/super_resolution_service.dart` |
| Configurações de leitura | `lib/src/setting/read_setting.dart` |
| Atalhos de teclado | `lib/src/setting/keyboard_shortcut_setting.dart` |
| i18n | `lib/src/l18n/en_US.dart`, `pt_BR.dart` |
| Workflow de build | `.github/workflows/build-windows-nomacs.yml` |
