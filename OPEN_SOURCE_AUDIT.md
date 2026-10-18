# DSAP 开源前审计

审计日期：2026-10-19（Asia/Tokyo）。结论：**NOT READY FOR PUBLIC RELEASE**。

负责人随后确认正式名称为 Digital Subtraction Angiography Perfusion Imaging（DSA-PI），作者为王嘉龙；机构未提供。原有代码路径、DSAP 标识和 DSAP-Toolkit 仓库名保持不变。负责人不记得 Su 核心灌注代码最初的仓库/压缩包，故该部分仍归为第三方改编，精确历史来源与许可证待核实；作者确认不解除第三方权利限制。

后续已明确授权检查通过后转 Public；当前仍 PRIVATE。已定位 Su 的 MATLAB 公开文件，其引用的更早源码为 GPLv3，相关实现有明确文本匹配。该新证据意味着统一“非商业”发布存在实质许可兼容问题，详见 `docs/CORE_LICENSE_REVIEW.md`。已生成 184 项运行源码候选及 SHA256（共 659,660 bytes，7 项启发式命中），只存放于本地审计目录，不代表已批准上传。官方 PyPI 已确认 NumPy 2.5.1、SciPy 1.18.0、pydicom 3.0.2 版本可获取，但全新安装测试尚未执行。

本次为全目录文件盘点、有限文本扫描、关键源文件/来源记录及许可证检查；不是对所有二进制、影像像素和历史数据完成脱敏认证。未修改既有核心算法、ROI Snapshot、保存生命周期或性能路径，未删除任何原项目文件，未重排现有目录。

## 范围与证据

本地详细清单由 `scripts/open_source_inventory.py` 生成到 `reports/open_source_audit/inventory.csv` 和 `summary.json`。清单列出逐文件路径、大小、B/C 分类、是否做过文本扫描、风险类别和行号，不复制命中的敏感值。**这些清单可能含敏感文件名，不允许提交。** 本文只保留安全的文件/目录示例与汇总结论。

完成的盘点快照：122,595 个实体文件，43,090,147,057 bytes（约 40.13 GiB）；121,809 项按数据/结果/运行库等规则归入 B，786 项需要 C 类复核（新文档的 A 类人工结论覆盖自动分类）。扫描了 492 个文本文件：41 个命中绝对路径，25 个命中患者字段/引用，152 个命中数字标识启发式，32 个命中第三方来源标记。75 个文件超过 50 MiB，30 个超过 100 MiB。24 个链接目录未跟随，枚举报告无读取错误。快照生成后本文及发布说明有少量文字更新，数量/字节数不是最终提交清单。

常见 credential 格式规则在已扫描文本中没有命中；不能据此排除未扫描范围、未知格式或配置中的秘密。264 个无后缀文件命中 DICOM preamble，位于本地工具/科学计算运行库/历史发行目录，可能包括第三方测试 fixtures，**不把这些签名直接宣称为真实患者数据**；仍全部隔离。真实临床结果的存在另由现有研究记录与脚本中的来源引用确认，未重新运行病例分析。

扫描边界：递归枚举项目实体文件，不跟随 junction/symlink，不扫描 `.git` 或自身输出。对源码/配置等非隔离目录内、不超过 2 MiB 的可识别文本执行路径、PHI 字段、8–12 位数字标识、常见 credential 格式与第三方来源启发式检查；安装包目录及已整体禁止上传的结果/历史/日志目录仅做文件盘点，不逐项进行文本扫描或内容清权。二进制、图像、较大文本及未识别格式保守隔离。无后缀文件检查 DICOM preamble 只能发现部分 DICOM，阴性不证明无医学影像。未执行 OCR、全面 DICOM 脱敏或完整秘密扫描器。

对两项小型 MAT 运行资源做了只读结构检查：默认分区模板包含 Format、OuterNormalized、InnerNormalized；Legacy 契约含 ValidationEvidence、AuditIdentity.Path、HumanReviewBundle 及 MATLAB function workspace。后者存在嵌入本地审计来源的风险，仍隔离；前者的几何来源授权尚未确认。没有把字段名检查当成完整二进制清权。

源码出现 PatientID 等字段可能只是合法读取逻辑；数字、token 变量或 license 示例也可能误报。反之，无命中不能证明无 PHI、账号或秘密。所有待确认项必须有明确处置后才能进入源码发布清单。

## A. 可以公开的文件（内容候选，不是公开授权）

仅新建、未包含病例数据的准备文档和占位说明：

- `README.md`、`OPEN_SOURCE_AUDIT.md`、`LICENSE_RECOMMENDATION.md`
- `CITATION.cff`（名称/作者已确认，无虚构版本或 DOI）、`CHANGELOG.md`、`CONTRIBUTING.md`
- `THIRD_PARTY_LICENSES.md`、`RELEASE_CHECKLIST.md`、`GIT_OPERATIONS.md`
- `.gitignore`、`docs/screenshots/README.md`、`examples/README.md`

这些文件是当前临时白名单。它们不能组成可运行的软件发行版，也不意味着现有源码永远不能公开。未列入 A 的文件一律保留本地，不按扩展名批量放行。

## B. 不应公开的文件

| 文件/目录类别 | 原因与处置 |
|---|---|
| `DSAP_results/`、`interactive_results/`、`python_results/`、`territory_results/`、`outputs/` | 临床影像衍生结果、MAT、曲线、掩膜、原图、来源路径与身份/序列关联信息；全部忽略 |
| `cohort_analysis/`、`artifact_build_*/`、`review_sheets_*/` | 队列、临床结局、研究表格与审阅材料；不得作 demo |
| `reports/`、`logs/`、`thumbnail_filter_backups/` | 可能含病例清单、完整路径、UID、截图、历史代码及本地审计证据 |
| `timeslice_current_rois.json`、`timeslice_roi_catalog.json`、`timeslice_serial_colors.json` | 当前/历史 ROI 与序列关联记录，不能作为通用配置公开 |
| DICOM（包括无扩展名）、Realm 数据库、NIfTI、患者 MAT/CSV/XLSX、图像与视频 | 可能含 PHI 或可识别像素；当前没有任何临床文件获准发布 |
| `.venv_cave/`、`cave_runtime/`、`.local_deps/`、`.model_deps/`、`.tools/`、`scipy_deps/`、所有 node_modules | 本地运行库、编译依赖、绝对路径与多重许可证；不直接复制进 Git |
| `release/`、`versions/`、压缩包、编译产物、自动保存、cache、临时文件 | 重复历史版本可能重新引入隐私或未清权代码；不随当前源码发布 |
| 模型权重及转换产物 | 当前普通 Git 清单中排除；再分发权、模型元数据及分发方案待确认，不表示所有模型法律上一律不能公开 |
| `.env*`、credentials/secrets、私钥、本地配置 | 忽略；如后续核实泄露真实密钥，先撤销/轮换，不能只依赖 .gitignore |

## C. 需要人工确认的文件

| 文件/范围 | 当前发现/所需确认 |
|---|---|
| 核心灌注代码，尤其 `modelfree_deconvolution_corrected.m` | 用户确认来自 Su；必须追溯原仓库、版本、许可、原作者声明和改动范围，归为改编代码 |
| 根目录 `dsap_*.m`、AutoAIF、src、scripts、tests | 逐文件确定原创/改编；测试与研究脚本包含真实病例引用，不能把所有 `.m`/`.py` 当成安全文本 |
| `test_native_gaussian_parity.m`、`audit_pending_results.m` | 已人工确认硬编码真实序列关联的历史结果路径；原样隔离，不在审计报告复述 UID |
| `README_CAVE_TRIAL.md` | 已人工确认含真实病例目录、原始数据路径及结果关联；不原样发布 |
| `README_PORTABILITY.md` | 含本机用户名路径和旧部署细节；新 README 已以通用说明替代，原文件保持不变且不放行 |
| `templates/default_partition_template.mat` | 运行资源，需确认内容、来源与是否含患者衍生形状；不能因为小而直接放行 |
| `templates/roi_aif_area_calibration.json` | 包含基于历史人工 AIF 的聚合校准，记录 HistoricalN=11；不是凭文件类型判定 PHI，但需确认研究资料使用权与披露许可 |
| `contracts/TIMESlice_Legacy_Orientation_Contract_v1.mat` | Legacy 运行契约，需检查是否嵌入病例 UID、路径、示例数据或特定受试者信息 |
| `timeslice_config.json`、`vascular_segmentation/config.yaml` | 区分可公开默认值与用户配置；保留现有运行文件，未来另提供审查过的 example |
| `启动TIMESlice方向审核.ps1` | 固定 MATLAB 安装路径；历史工具不能作为通用启动方式承诺 |
| model provenance / sidecar、训练清单和模型目录 | 来源哈希可有助复现，但训练记录、类别文件和实际权重仍需分别清权与隐私检查 |
| 全部 screenshot、MAT 和二进制示例 | 没有获准的真实病例示例；placeholder 不能算 basic workflow 已通过 |

## D. 第三方代码及其许可证

详细逐组件记录见 `THIRD_PARTY_LICENSES.md`。关键区分：

1. **候选原创：** 项目专属 UI、流程、ROI/结果集成和部分几何辅助；需要权利人确认，不因缺少版权头就认定原创。
2. **修改后的第三方代码：** 用户确认的 Su 灌注代码，CAVE 预处理/推理适配，autoTICI 相关模型转换和供血区适配。
3. **直接第三方依赖：** CAVE 源码/模型、VTI、arc_length、PyTorch/科学计算依赖、Realm/Node、MATLAB/Image Processing Toolbox、可选 nnUNet 相关组件。

CAVE 与当前 perfDSA 的 MIT 文本附有 Commons Clause；当前 VTI GitHub 来源有非商业条件，不能用另一个 File Exchange 版本的 BSD 标签覆盖。CAVE 内还存在 ConvLSTM/UNet-Zoo/gist 借用声明，许可证链未闭合。没有删除或改写任何原始许可证。

## E. 潜在版权风险

- Su 衍生核心的精确来源版本尚未锁定；当前 Python perfDSA 或旧 GitLab 项目只能作线索，不得替未知历史版本编造许可。
- 文章可阅读、代码可下载、模型公开可获取，都不等于可以任意重新授权。
- 全项目的 MIT/Apache 许可目前不可直接授予；机构与合作研究权属尚未确认。
- VTI 多来源许可不同、CAVE 间接借用和模型派生权利需要分别解决。
- 本地安装的第三方 binaries、训练/测试数据、上游截图/示例也可能各自有独立权利；不能连同运行库一起上传。

## F. 潜在患者隐私风险

- 原始 DICOM 元数据、像素内文字、序列 UID、生日和检查日期，及无扩展名 DSA 文件。
- 核心结果与 ROI Snapshot/Legacy 导入记录可能保留 source path、源身份、图像、ROI、临床关联；本次不修改这些稳定保存机制，而是阻止结果进入 Git。
- CSV/JSON/日志/测试代码/README 也可能保存患者关联信息，不能只排除 DICOM。
- 去姓名、替换文件名或只删 DICOM header 不足以证明不可重新识别。当前未对任何真实病例作公开授权或脱敏认证。
- 审计清单本身包含原文件名，因此只能留本地。GitHub PRIVATE 仍属于上传，不能绕过隐私检查。

## 大文件与分发建议

已实测 CAVE AV 权重为 332,731,061 bytes；另一 CAVE 权重副本同量级；供血区原始权重为 236,832,518 bytes、TorchScript 为 237,368,239 bytes；另有超过 100 MiB 的 PyTorch wheel。均不适合普通 Git。

[GitHub 官方限制](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)：超过 50 MiB 警告，超过 100 MiB 拒绝普通 Git 推送。当前不配置 LFS 或上传模型。优先记录原作者固定版本下载来源及 SHA256；如必须再分发，先确认许可，稳定模型适合经用户另行批准的 Release asset，确需版本化的大文件再评估 Git LFS 配额和 clone 行为。真实患者数据不因使用 LFS/Release 就变得可发布。

## 目录结构与后续门槛

保持所有现有程序位置不变，新增文档与占位目录不改变算法路径。建议今后建立显式 release manifest、可复现依赖安装与 model acquisition 清单，并把本地配置与 example 配置区分；这些是建议，未执行源文件迁移。

本机 Git 2.53.0 可用；用户随后安装 GitHub CLI 2.102.0 并完成浏览器认证，已核实账号为 Jialong-Wang97，随后初始化本地 main 分支。当前只允许已审查的 12 个文档/占位文件进入准备提交；这不解除源码、数据与模型的隔离。已执行的 Git 操作见 `GIT_OPERATIONS.md`。源码上传前仍须完成清单审查，不能直接 `git add .` 或不经检查 `gh repo create --push`。远程与 clean-clone 状态见 `RELEASE_CHECKLIST.md`。
