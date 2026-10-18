# License recommendation — decision pending

**当前选择：接受商业使用，评估 GPL 发布。** 用户已放弃对整体施加统一非商业限制的要求。Su 的公开 MATLAB 文件引用 GPLv3 上游，且相关实现匹配；仍不能推定 Su 特定贡献的授权，也不能将较新 Python perfDSA 的 Commons Clause 移用于旧 MATLAB 文件。建议对清权后的核心/原创部分采用适用的 GPL 条款，分别解决 CAVE/供血区模型和 VTI 的分发兼容问题。完整评估见 `docs/GPL_DISTRIBUTION_PLAN.md`。

尚未创建顶层 LICENSE，没有替用户授予许可。项目名称已确认为 Digital Subtraction Angiography Perfusion Imaging（DSA-PI），作者为王嘉龙；机构未提供。作者署名不等于完整权属清理，仍须确认单位/雇佣或合作研究权属，以及所有改编代码来源；文件命名或本地创建时间不能证明原创。

对于确有权授权、与 GPL 核心构成同一程序的原创部分，当前优先评估 GPL-compatible 发布；MIT/Apache 不再作为整个集成软件的默认建议。最终 GPL 版本表达式与文件范围需依据实际授予条款确定，不能覆盖第三方原有条件。

当前整体包不能声明为无条件 MIT 或标准宽松开源：CAVE 的本地许可证包含 Commons Clause；VTI 的实际 GitHub 来源头部限制非商业应用。保留并隔离这些组件及原作者声明，不通过给整个仓库贴 MIT 标签消除限制。必要时只发布已清权的原创部分并要求用户独立依法获取第三方依赖；不为规避条款修改核心算法。

autoTICI 权重、其 TorchScript 派生物、CAVE 权重与间接借用代码还需分别完成许可证链确认。代码许可证不能自动推定为模型、训练数据或示例影像的授权。

本文件是基于现有许可证文本的工程发布建议，不是已完成的法律清权。详细证据和未决项见 THIRD_PARTY_LICENSES.md。
