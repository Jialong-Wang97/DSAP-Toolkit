# DSAP-Toolkit

**发布准备中；当前不是可从 GitHub 独立安装的发行版。Research Use Only。**

DSAP 是基于 MATLAB 的数字减影血管造影（DSA）灌注分析研究软件。正式英文全称待项目负责人确认；描述性暂译为 *Digital Subtraction Angiography Perfusion*，不能据此认定正式名称或作者信息。

## 功能

以下由当前本地源代码及模块说明核实；不表示这些源文件已经纳入发布清单。

- DICOM 文件/文件夹序列选择、原生 ROI 编辑及可选 TIMESlice Legacy ROI/AIF 导入。
- 手动 AIF；AutoAIF V2 使用准备阶段的血管/中心线/曲率生成血管腔内候选，QC 通过后应用，失败回到人工选择；最终仍需确认。
- 组织 ROI、上下界、冻结的 ROI Snapshot、组织及独立动静脉结果查看。
- CAVE AV 分割与人工复核血管排除区；TSVD 反卷积、TIC/IRF 与 CBF/CBV/MTT/Tmax 图。
- ROI 分布统计；二维投影血管中心线、曲率及 VTI 几何分析。
- 可选 ACA/MCA 自动供血区候选、标签/侧别人工校核与编辑；受模型依赖与许可证限制。
- 患者/序列批处理辅助、结果保存及按需导出。自动化不替代人工质量控制。

## 截图

位置预留为 `docs/screenshots/`。目前没有可公开截图；只允许未来加入 synthetic 图像及人工核查无患者信息的界面截图。

## 环境与依赖

现有移机记录报告 Windows x64、MATLAB R2024b Update 2 和 Image Processing Toolbox。MATLAB 必须单独授权安装。Python 3.12 x64、PyTorch 2.6.0 CPU、NumPy、SciPy、scikit-image、pydicom、Pillow、pylibjpeg 及其解码插件用于 CAVE；精确依赖锁定与公开安装流程尚未交付。Legacy 导入额外依赖 Node、Realm 12.14.2 和用户自己的合法 TIMESlice 数据。供血区模块需要单独的模型和配置。

MATLAB Signal Processing Toolbox 不因 `gausswin` 被强制要求，项目存在同名本地实现；该实现的来源仍需确认。历史环境检查通过不等于当前 clean-clone 验收。

## 安装与快速开始

**当前阻塞：** `.gitignore` 暂时仅允许发布准备文档。源代码、模板、模型与运行库仍在本地隔离审查，当前 clone 不能运行软件。不要把本地 venv、真实病例或完整研究目录上传以绕过这个问题。

以下是完整且经授权配置的本地源码目录的现有入口，不是已通过验证的 GitHub 安装教程：

1. 安装 MATLAB R2024b + Image Processing Toolbox 与 Python 3.12 x64。
2. 按未来经审核的依赖清单准备 Python 环境、固定版本 CAVE 源码与权重，以及检查过的 MAT 模板。此步骤当前尚无可复现的公开安装脚本。
3. 在项目根目录运行 `首次运行_配置DSAP.bat`。现有脚本只重绑定已有环境并检查资源，不会自动安装缺失 packages 或模型。
4. 环境通过后运行 `启动DSAP分析_去除大血管.bat`。也可在 MATLAB 切换到项目目录后检查并启动：

```matlab
addpath(pwd);
report = dsap_environment_check('native');
assert(report.NativePass, 'Native dependencies are incomplete');
dsap_workspace;
```

已创建 [DSAP-Toolkit 私有仓库](https://github.com/Jialong-Wang97/DSAP-Toolkit)，目前只保存发布准备文档；无权限的访问者无法查看。源码上传与可运行发行版仍待审计阻塞项解决。首次文档提交已从 GitHub 成功 clone，但 setup → launch → basic workflow 尚未通过。

## 推荐工作流程

选择合法的 DSA 输入 → 检查序列、方向、极性与时间轴 → 血管准备 → 审核 AIF/ROI/颅内上下界 → 复核血管排除 → 确认 ROI Snapshot → 灌注计算 → 检查曲线、有效性与覆盖率 → 保存核心结果 → 按需导出。TIMESlice 导入须先在来源软件保存 ROI，并在 DSAP 核对来源与方向。

## 输入与输出

输入为具有可用帧时间信息的 DSA DICOM 序列；当前 CAVE 适配器针对已确认的暗血管输入。时间、极性或来源不明时不能猜测。内部常用数组约定为 `[time,row,column]`，这不是对任意 MAT 文件的通用导入承诺。Legacy 输入需要匹配的 Realm 数据库、影像与 ROI。

核心结果与导出包括 MAT、参数/覆盖率 CSV、原始及处理后 TIC、IRF、灌注图、血管分割与审核记录。常见本地目录为 `interactive_results/`、`outputs/`、`territory_results/`。这些结果可能包含原图、掩膜、患者标识、来源路径及可关联的 UID；默认全部不进 Git。

## 灌注参数

以 `modelfree_deconvolution_corrected.m` 为准，TSVD 截断比例默认 0.15，时间步长 `dt` 使用秒；处理路径可启用居中的时间高斯滤波。

| 参数 | 当前计算定义 | 解释边界 |
|---|---|---|
| CBF | IRF 时间维最大值 | 相对血流指标；未校准为临床绝对流量 |
| CBV | `dt * sum(IRF)` | 相对血容量指标 |
| MTT | `CBV / (CBF + 1e-9)` | 平均通过时间的计算指标，受数值有效性影响 |
| Tmax | `dt * (峰索引 - 1)` | 零起点 IRF 峰值延迟，秒 |

DSA 为二维投影，重叠、运动、注射条件、采样、AIF 与 ROI 都会影响结果。血管内参数不能直接作为组织灌注解释；不要未经标定标注 `mL/100g/min`。

## AIF、ROI 与大血管

AutoAIF 为工程启发式，不承诺精确 ICA C4/C5 定位。手工修改及最终冻结的 ROI 优先于较早的自动候选记录。Native ROI 与 Legacy 导入均需审核来源、空间方向与分析范围。

CAVE AV 的动静脉并集使用 sigmoid 0.5 阈值，可能包含细血管，不能把名称“大血管处理”理解为只排除大管径。复核可增加排除或恢复组织；组织统计排除最终血管区与 AIF。中心线/曲率属于几何与 AIF 辅助模块，不是对 CAVE 分割的额外精度保证。

## 示例与限制

`examples/README.md` 是 placeholder，没有真实患者 demo。未来优先提供 synthetic 输入及预期输出。已知发布阻塞包括许可证链、原创权属、依赖可复现安装、MAT 资源审查、正式名称/作者以及 clean-clone 测试；见 `RELEASE_CHECKLIST.md`。供血区类别映射有上游注释/代码不一致的历史证据，必须人工复核；可选 nnUNetv2 后端不能宣称已经验收。

## Citation

`CITATION.cff` 为待确认草稿，尚无正式作者、DOI、版本或发表年份承诺。发布前由权利人确认作者列表，补齐正式引用；使用第三方方法时同时引用原工作。

## References

- 核心灌注代码由项目负责人确认使用了 Su 的代码；精确历史版本仍待追溯。[perfDSA 作者项目](https://github.com/RuishengSu/perfDSA) 与 [早期 perfusionDSA](https://gitlab.com/radiology/igit/q-maestro/perfusiondsa) 是来源核对线索，不将当前代码宣称为完全原创。
- [CAVE: Cerebral Artery-Vein Segmentation in Digital Subtraction Angiography](https://arxiv.org/abs/2208.02355)；[作者代码](https://github.com/RuishengSu/CAVE_DSA)。
- Khansari et al., *Method for quantitative assessment of retinal vessel tortuosity in optical coherence tomography angiography applied to sickle cell retinopathy*, 2017，[DOI](https://doi.org/10.1364/BOE.8.003796)。
- [autoTICI 作者代码](https://github.com/RuishengSu/autoTICI)；具体模型来源与限制见 `THIRD_PARTY_LICENSES.md`。
- [Direct vascular territory segmentation on cerebral digital subtraction angiography](https://arxiv.org/abs/2508.13821)：自动 ACA/MCA ROI 的参考方法，当前本地实现使用其相关公开网络权重，不是 atlas registration。

## License / Research Use Only

尚未授予项目整体开源许可证；`LICENSE_RECOMMENDATION.md` 只是建议。第三方条款独立适用，CAVE/相关模型及当前 VTI 来源存在限制，不能把整个包称为 MIT。未经权属与许可证确认不得公开发布。

For research use only. Not a medical device or a validated clinical decision-making system. No diagnostic or treatment use is claimed. 人工审核及本地研究验证不构成临床有效性、监管批准或安全性认证。
