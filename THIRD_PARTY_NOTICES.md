# Hinweise zu fremden Lizenzen

Flow ist ein eigenständiges Programm von **Sinthex**. Es nutzt die folgenden Open-Source-Projekte als Basis. Deren Lizenzen bleiben unberührt. Die Lizenz von Flow selbst steht in [LICENSE](LICENSE) (MIT, Copyright (c) 2026 Sinthex).

## Direkt verwendet

| Projekt | Wofür | Lizenz | Quelle |
| --- | --- | --- | --- |
| [mlx-whisper](https://github.com/ml-explore/mlx-examples) 0.4.3 | Spracherkennung auf Apple Silicon | MIT, Copyright © 2024 Apple Inc. | MLX Contributors |
| [MLX](https://github.com/ml-explore/mlx) | Rechenbibliothek für Apple Silicon | MIT, Copyright © 2023 Apple Inc. | MLX Contributors |
| [mlx-vlm](https://github.com/Blaizzy/mlx-vlm) | Optionale lokale Korrektur | MIT, Copyright © 2025 Prince Canuma | Prince Canuma |
| [Whisper](https://github.com/openai/whisper) large-v3-turbo | Modellgewichte, über `mlx-community/whisper-large-v3-turbo` | MIT, Copyright (c) 2022 OpenAI | OpenAI |

Die Modellkarte von [openai/whisper-large-v3-turbo](https://huggingface.co/openai/whisper-large-v3-turbo) nennt die Lizenz **MIT**. Die MLX-Fassung [mlx-community/whisper-large-v3-turbo](https://huggingface.co/mlx-community/whisper-large-v3-turbo) ist eine Konvertierung dieses Modells.

## MIT-Lizenztexte der Basis

Die MIT-Lizenz verlangt, dass Copyright-Hinweis und Erlaubnistext bei Weitergabe erhalten bleiben. Die Texte der Projekte, auf denen Flow aufsetzt:

### mlx-whisper und MLX

```
MIT License

Copyright © 2023 Apple Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

mlx-whisper trägt zusätzlich im Quelltext `Copyright © 2024 Apple Inc.` und ist unter derselben MIT-Lizenz veröffentlicht: <https://github.com/ml-explore/mlx-examples>.

### mlx-vlm

```
MIT License

Copyright © 2025 Prince Canuma

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Whisper

```
MIT License

Copyright (c) 2022 OpenAI

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Weitere Laufzeitabhängigkeiten

`mlx-whisper` und `mlx-vlm` ziehen beim Installieren weitere Pakete. Flow verändert sie nicht. Maßgeblich sind die Lizenzen in den jeweiligen Distributionen, unter anderem:

| Paket | Lizenz |
| --- | --- |
| numpy | BSD-3-Clause sowie weitere in der Distribution genannte Lizenzen |
| huggingface_hub | Apache-2.0 |
| torch | Apache-2.0 und weitere in der Distribution genannte Lizenzen |
| numba | BSD |
| scipy | BSD, Copyright (c) 2001-2002 Enthought, Inc. 2003, SciPy Developers |
| tiktoken | MIT, Copyright OpenAI |

Die vollständigen Hinweise liegen nach der Installation unter `~/Library/Application Support/Flow/.venv/` in den `*.dist-info`-Ordnern.
