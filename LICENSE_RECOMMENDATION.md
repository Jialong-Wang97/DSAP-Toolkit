# License recommendation — decision pending

**新发现：核心来源链涉及 GPLv3。** Su 的公开 MATLAB 文件引用 liob/non-parametric_deconvolution，且相关卷积核/SVD 代码匹配。不能给潜在 GPL 衍生核心直接加“禁止商业使用”条款，也不能假定较新 Python perfDSA 的 Commons Clause 自动覆盖旧 MATLAB 文件。用户已表示希望非商业发布；需要额外适用授权，或由用户接受后进一步评估 GPL 及其他组件兼容方案。证据见 `docs/CORE_LICENSE_REVIEW.md`。

尚未创建顶层 LICENSE，没有替用户授予许可。项目名称已确认为 Digital Subtraction Angiography Perfusion Imaging（DSA-PI），作者为王嘉龙；机构未提供。作者署名不等于完整权属清理，仍须确认单位/雇佣或合作研究权属，以及所有改编代码来源；文件命名或本地创建时间不能证明原创。

对于确有权授权的原创部分，可考虑 MIT（简洁）或 Apache-2.0（明确专利许可条款）。这两种选择都不能覆盖第三方原有条款。具体选用及授权主体需要权利人决定。

当前整体包不能声明为无条件 MIT 或标准宽松开源：CAVE 的本地许可证包含 Commons Clause；VTI 的实际 GitHub 来源头部限制非商业应用。保留并隔离这些组件及原作者声明，不通过给整个仓库贴 MIT 标签消除限制。必要时只发布已清权的原创部分并要求用户独立依法获取第三方依赖；不为规避条款修改核心算法。

autoTICI 权重、其 TorchScript 派生物、CAVE 权重与间接借用代码还需分别完成许可证链确认。代码许可证不能自动推定为模型、训练数据或示例影像的授权。

本文件是基于现有许可证文本的工程发布建议，不是已完成的法律清权。详细证据和未决项见 THIRD_PARTY_LICENSES.md。
