# Third-party notices

## Matt Pocock skills

The eleven skills in `skills/dev-workflow/` and `skills/writing-for-agents` come
from [mattpocock/skills](https://github.com/mattpocock/skills). Batman checked
all source directories against upstream `main` at commit
[`4588b32ecab9ecc9fc8cc6b6c5e7d675b6004b0d`](https://github.com/mattpocock/skills/commit/4588b32ecab9ecc9fc8cc6b6c5e7d675b6004b0d)
on October 5, 2026. Their `source/SOURCE.md` files record each snapshot's
path, commit, and dates. Snapshots pinned to earlier commits have identical
content at the checked revision.

The owner requested an upstream reset on October 5, 2026. Active skill files,
including supporting files and agent metadata, are restored byte-for-byte
from upstream. Batman's installer continues to derive target invocation
metadata and preserve installed local overrides.

`skills/experimental/prototype` is an unmodified copy of
`skills/engineering/prototype` at commit
[`959a8e9f1edc3adbe2f7e3054bb6fbefa6696260`](https://github.com/mattpocock/skills/commit/959a8e9f1edc3adbe2f7e3054bb6fbefa6696260).
Its complete directory matches the checked upstream revision above, including
`agents/openai.yaml`. Batman records its pinned content hash in
`skills/experimental/sources.tsv`.

MIT License

Copyright (c) 2026 Matt Pocock

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

## pstack skills

`skills/communication/unslop` is adapted from [pstack](https://github.com/cursor/plugins/tree/main/pstack), using the local snapshot in `~/skills-db/pstack` on September 12, 2026. Batman narrows its description to durable human-facing prose; the rule body is unchanged. `skills/communication/bro` was supplied from the same project by the repository owner on September 15, 2026 and is unchanged.

Both skills preserve their complete upstream directories in `source/` at
cursor/plugins commit
[`e5a8186d7b43be8d6ac4452440fbead5f1a51c70`](https://github.com/cursor/plugins/commit/e5a8186d7b43be8d6ac4452440fbead5f1a51c70),
downloaded October 5, 2026. Their `source/SOURCE.md` files are Batman metadata.
These reference snapshots do not establish the original revisions used for the
earlier copies and adaptations.

MIT License

Copyright (c) 2026 Lauren Tan

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
