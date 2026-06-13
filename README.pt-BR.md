# proton-pack 📦

> Empacote qualquer jogo instalado localmente como um AppImage portátil — com GE-Proton embutido ou vinculado ao sistema.

[![Licença: MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-yellow.svg)](LICENSE)
[![Plataforma: Linux](https://img.shields.io/badge/plataforma-Linux-blue.svg)](https://kernel.org)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![PRs Bem-vindos](https://img.shields.io/badge/PRs-bem--vindos-brightgreen.svg)](CONTRIBUTING.md)

**proton-pack** é uma ferramenta CLI open source que lê um jogo instalado localmente (via Steam, Heroic, GOG, Epic ou qualquer diretório), detecta se ele precisa do Proton para rodar no Linux, e gera um arquivo `.AppImage` pronto para executar em qualquer distribuição Linux — sem necessidade de instalação.

🇬🇧 [Read in English](README.md)

---

## Por que o proton-pack?

| Ferramenta | Gera AppImage | Inclui Proton | Funciona com qualquer store |
|---|---|---|---|
| Lutris | ✗ | ✗ | ✓ |
| Bottles | ✗ | ✗ | ✓ |
| ProtonUp-Qt | ✗ | só gerencia | — |
| Heroic | ✗ | ✗ | ✓ |
| **proton-pack** | **✓** | **✓** | **✓** |

O proton-pack preenche uma lacuna que nenhuma ferramenta existente cobre: converter um jogo já instalado em um AppImage portátil e executável — incluindo a camada de compatibilidade Proton-GE quando necessário.

---

## Funcionalidades

- **Detecção automática** — lê manifestos `.acf` da Steam ou aceita qualquer diretório de jogo
- **Nativo vs Windows** — detecta binários ELF (Linux nativo) ou arquivos `.exe` (requer Proton)
- **Suporte ao GE-Proton** — localiza instalações existentes do GE-Proton ou embute uma dentro do AppImage
- **Modo vinculado** *(padrão)* — AppImage leve que usa o GE-Proton já instalado no sistema
- **Modo embutido** — AppImage totalmente portátil (~800 MB+) com GE-Proton incluído
- **Multi-store** — funciona com Steam, Heroic (Epic/GOG/Amazon) ou qualquer diretório de jogo
- **Extração de ícone** — busca ícones automaticamente do cache de biblioteca da Steam
- **Ciente do WINEPREFIX** — usa o `compatdata` existente para preservar saves e configurações

---

## Requisitos

```bash
# Obrigatórios
bash >= 5.0
file
patchelf
libfuse2        # para montagem do AppImage

# Baixar o appimagetool
wget -O ~/bin/appimagetool \
  "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x ~/bin/appimagetool

# GE-Proton (para jogos Windows) — instale via protonup-qt ou manualmente:
# https://github.com/GloriousEggroll/proton-ge-custom/releases
```

---

## Instalação

```bash
# Clone o repositório
git clone https://github.com/SEU_USUARIO/proton-pack.git
cd proton-pack

# Torne o script executável
chmod +x proton-pack.sh

# Opcional: adicionar ao PATH
sudo ln -s "$(pwd)/proton-pack.sh" /usr/local/bin/proton-pack
```

---

## Uso

### Jogo da Steam (por App ID)

```bash
# Liste seus App IDs instalados
ls ~/.steam/steam/steamapps/appmanifest_*.acf | grep -oP '\d+(?=\.acf)'

# Empacotar um jogo (modo leve — usa GE-Proton do sistema)
./proton-pack.sh --steam 1245620

# Empacotar com GE-Proton embutido no AppImage (totalmente portátil)
./proton-pack.sh --steam 1245620 --bundle-proton
```

### Qualquer diretório de jogo

```bash
# Jogo nativo Linux
./proton-pack.sh --dir /caminho/do/jogo --exe binario_do_jogo --name "Meu Jogo"

# Jogo Windows com GE-Proton vinculado
./proton-pack.sh --dir /caminho/do/jogo --exe Jogo.exe --name "Meu Jogo"

# Jogo Windows com GE-Proton embutido
./proton-pack.sh --dir /caminho/do/jogo --exe Jogo.exe --name "Meu Jogo" --bundle-proton
```

### Variáveis de ambiente

| Variável | Padrão | Descrição |
|---|---|---|
| `STEAM_ROOT` | `~/.steam/steam` | Caminho de instalação da Steam |
| `OUTPUT_DIR` | `~/AppImages` | Onde os AppImages serão salvos |
| `APPIMAGETOOL` | `~/bin/appimagetool` | Caminho para o binário appimagetool |
| `STEAM_COMPAT_DATA_PATH` | detectado automaticamente | Override do caminho do WINEPREFIX |

Veja [docs/usage.md](docs/usage.md) (em inglês) para o guia completo, incluindo múltiplas bibliotecas, seleção de executável e troubleshooting.

---

## Como funciona

```
Entrada (App ID Steam / diretório do jogo)
        │
        ▼
 Lê metadados (manifesto .acf ou flags)
        │
        ▼
 Detecta tipo ──► Linux nativo ──► Copia ELF + libs → AppDir
        │
        └────────► Windows (.exe) ──► Localiza ou embute GE-Proton
                                               │
                                               ▼
                                         Monta AppRun com
                                         wrapper proton run
                                               │
                                               ▼
                                     appimagetool → .AppImage
```

### Modo vinculado (padrão)

O AppImage gerado é leve. O script `AppRun` localiza o GE-Proton em tempo de execução nos caminhos padrão:

```
~/.steam/steam/compatibilitytools.d/GE-ProtonX-XX/
~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d/
~/snap/steam/common/.steam/steam/compatibilitytools.d/
```

### Modo embutido (`--bundle-proton`)

O GE-Proton é copiado para dentro do AppDir antes do empacotamento. O AppImage gerado é auto-suficiente e roda em qualquer máquina Linux sem nenhuma configuração prévia. Um arquivo `LICENSES/PROTON_NOTICE.txt` é gerado automaticamente para conformidade com a LGPL.

---

## Integração com o Heroic Games Launcher

O proton-pack foi projetado para funcionar bem junto ao [Heroic Games Launcher](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher).

Se você usa o Heroic para instalar jogos da GOG ou Epic, pode empacotá-los como AppImages:

```bash
# Jogo GOG instalado via Heroic (caminho padrão)
./proton-pack.sh \
  --dir "$HOME/Games/Heroic/MeuJogo" \
  --exe "MeuJogo.exe" \
  --name "Meu Jogo" \
  --bundle-proton
```

Veja o guia completo em [docs/heroic-integration.md](docs/heroic-integration.md) (em inglês), incluindo notas sobre separação de saves/prefix e possível integração futura.

---

## Limitações

| Cenário | Comportamento |
|---|---|
| Jogos com DRM da Steam | O AppImage roda, mas a Steam pode precisar estar aberta |
| Anti-cheat (EAC, BattlEye) | Pode não funcionar — anti-cheat costuma exigir o launcher original |
| WINEPREFIX | Sempre armazenado fora do AppImage (saves são preservados) |
| Multiplayer com VAC | Não recomendado — jogue diretamente pela Steam |

---

## Estrutura do projeto

```
proton-pack/
├── proton-pack.sh        # Ponto de entrada principal
├── lib/
│   ├── detect.sh         # Detecção de tipo de jogo e executável
│   ├── proton.sh         # Localizador e empacotador do GE-Proton
│   ├── appdir.sh          # Construtor da estrutura AppDir
│   └── metadata.sh        # Leitor de manifesto e buscador de ícone
├── docs/
│   ├── usage.md          # Guia de uso estendido
│   ├── heroic-integration.md
│   └── legal.md
├── LICENSES/             # Avisos de licença de terceiros (Wine, Proton)
└── .github/              # Templates de issue e CI
```

---

## Contribuindo

Contribuições são muito bem-vindas! Leia o [CONTRIBUTING.md](CONTRIBUTING.md) (em inglês) antes de abrir um pull request.

Áreas onde a ajuda é especialmente apreciada:

- Testes com mais jogos e stores
- Melhorias na detecção de caminhos para macOS, Flatpak e Snap
- Wrapper gráfico (Zenity / Yad / Electron)
- Interface de plugin para o Heroic Games Launcher

---

## Aviso legal

Esta ferramenta não redistribui nenhum arquivo da Steam, do Proton ou dos jogos.  
Ela apenas reorganiza arquivos já legalmente adquiridos e instalados pelo usuário.

- Não é afiliada à Valve Corporation nem ao GloriousEggroll
- Os usuários são responsáveis por cumprir os termos de licença de cada jogo empacotado
- Jogos com DRM podem não funcionar corretamente quando executados fora da Steam
- Steam® é marca registrada da Valve Corporation
- GE-Proton é um projeto de GloriousEggroll — [componentes MIT + LGPL](LICENSES/)

Veja [docs/legal.md](docs/legal.md) (em inglês) para uma análise completa.

---

## Licença

Este projeto está licenciado sob a **Licença MIT** — veja [LICENSE](LICENSE) para detalhes.

---

<div align="center">
  Feito com ❤️ para a comunidade de jogos no Linux
</div>
