% Copyright (C) 2026 王嘉龙. SPDX-License-Identifier: GPL-3.0-only
function w = gausswin(n, alpha)
%GAUSSWIN Gaussian window without Signal Processing Toolbox.
%   W = GAUSSWIN(N) returns an N-point Gaussian column vector. The default
%   ALPHA is 2.5, matching the Signal Processing Toolbox implementation.

    narginchk(1, 2);
    validateattributes(n, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'integer', 'positive'}, mfilename, 'n');
    if nargin < 2
        alpha = 2.5;
    end
    validateattributes(alpha, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, mfilename, 'alpha');

    sample_positions = (-(n - 1) / 2:(n - 1) / 2)';
    w = exp(-0.5 * (alpha * sample_positions / (n / 2)).^2);
end
