# Permission inquiry draft — not sent

Subject: License clarification for MATLAB perfusion deconvolution used in DSA-PI

Dear Dr. Su,

I am 王嘉龙, the author of Digital Subtraction Angiography Perfusion Imaging (DSA-PI), a MATLAB-based DSA perfusion research application. I would like to make its source available on GitHub for non-commercial research, while preserving original attribution and license notices.

The perfusion core was adapted from your code, although I no longer have a reliable record of the original downloaded archive. During release preparation we located your `modelfree_deconvolution.m` in the GitLab perfusionDSA project, commit `2adaa974e4e46e9e4ef2535ba515ed49329706bc`. Its header links to `liob/non-parametric_deconvolution`, which carries GPLv3. We have not assumed that the separate Commons Clause license in the newer Python perfDSA repository applies to this earlier MATLAB code.

Could you please clarify:

1. Which license applies to the MATLAB file and your modifications, including whether a separate license notice or written permission exists?
2. Whether a non-commercial redistribution grant is available for your contributions, and whether permission from the earlier upstream author(s) is also required?
3. Which copyright notices, modification statements and citations should be retained?
4. Whether the grant would cover public GitHub source distribution and redistribution of our modified implementation, rather than only internal research use?

The intended application also uses CAVE vessel segmentation and a separately reviewed territory segmentation model. Their licenses and model permissions will be handled independently. We do not want to add restrictions incompatible with GPL or remove any upstream attribution. We can provide a focused source comparison for review without sharing patient data.

Thank you for helping us distribute this work correctly.

王嘉龙

---

Maintainer notes: no affiliation, contact address or permission is invented here. Send through an independently verified author contact only after reviewing the draft. A response must cover the relevant rights; silence is not permission. No message has been sent by the assistant.
