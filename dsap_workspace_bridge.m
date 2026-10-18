function varargout=dsap_workspace_bridge(action,varargin)
% Run-scoped UI adapter. No scientific data, cache, or observer graph.
persistent current
if strcmp(action,'bind'),current=varargin{1};return;end
if strcmp(action,'unbind'),current=[];return;end
active=~isempty(current)&&isgraphics(current.Figure);
if strcmp(action,'active'),varargout={active};return;end
if ~active
 if nargout,varargout={[]};end
 return
end
if strcmp(action,'get'),varargout={current};return;end
[varargout{1:nargout}]=current.Dispatch(action,varargin{:});
end
