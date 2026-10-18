> Historical assessment. Current scope/status is in ../THIRD_PARTY.md and ../REVIEWER_RELEASE_CHECKLIST.md. The latest user instruction requires renewed explicit permission before Public visibility or a formal Release. Earlier authorization statements below are superseded.

# Permission inquiry draft — not sent

Subject: License clarification for MATLAB perfusion deconvolution used in DSA-PI

Dear Dr. Su,

I am 王嘉龙, the author of Digital Subtraction Angiography Perfusion Imaging (DSA-PI), a MATLAB-based DSA perfusion research application. I would like to make its source available on GitHub under an appropriate GPL-compatible license, including the commercial-use rights required by GPL, while preserving original attribution and license notices.

The perfusion core was adapted from your code, although I no longer have a reliable record of the original downloaded archive. During release preparation we located your `modelfree_deconvolution.m` in the GitLab perfusionDSA project, commit `2adaa974e4e46e9e4ef2535ba515ed49329706bc`. Its header links to `liob/non-parametric_deconvolution`, which carries GPLv3. We have not assumed that the separate Commons Clause license in the newer Python perfDSA repository applies to this earlier MATLAB code.

Could you please clarify:

1. Which license applies to the MATLAB file and your modifications, including whether a separate license notice or written permission exists?
2. Whether your MATLAB contributions were distributed under the cited upstream GPL terms, or whether you can provide an explicit GPL-compatible redistribution grant for your contributions? Please also identify any additional upstream rights or permissions that must be addressed.
3. Which copyright notices, modification statements and citations should be retained?
4. Whether the grant would cover public GitHub source distribution and redistribution of our modified implementation, rather than only internal research use?

The intended application also uses CAVE vessel segmentation and a separately reviewed territory segmentation model through Python processes exchanging image/mask files. Their Commons Clause terms and model permissions will be handled independently; we are not assuming that a subprocess automatically settles compatibility. If you can clarify a supported independent-component distribution or offer compatible permission for those components, that would also help. We do not want to add restrictions incompatible with GPL or remove any upstream attribution. We can provide a focused source comparison for review without sharing patient data.

Thank you for helping us distribute this work correctly.

王嘉龙

---

Maintainer notes: no affiliation, contact address or permission is invented here. Send through an independently verified author contact only after reviewing the draft. A response must cover the relevant rights; silence is not permission. No message has been sent by the assistant.
