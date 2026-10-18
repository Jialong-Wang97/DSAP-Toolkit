function [ICA_candidate_centerline,detail]=find_ICA_segment(mask,network,spacing)
% Infer terminal ICA from the largest connected skeleton and two distal arms.
% Unlabelled projection topology cannot certify MCA/ACA or C4/C5 anatomy.
% Optional RootNode and TerminalNode in network encode reviewed anatomy.
ICA_candidate_centerline=[];detail=struct('Available',false,'Reason','','AnatomyConfirmed',false);
assert(numel(spacing)==2&&all(isfinite(spacing))&&all(spacing>0),'AutoAIF:Spacing','Calibrated [row column] spacing required.');
if isempty(network),network=build_centerline_graph(mask,spacing);end
G=network.Graph;xy=network.XY;scale=reshape(spacing([2 1]),1,2);
assert(isa(G,'graph')&&isequal(size(xy),[numnodes(G) 2])&&all(isfinite(xy),'all'),'AutoAIF:Graph','Graph needs one finite XY coordinate per node.');
assert(all(interp2(double(mask),xy(:,1),xy(:,2),'nearest',0)>.5),'AutoAIF:Graph','Centerline nodes must lie inside the existing vessel mask.');
if numnodes(G)<3,detail.Reason='No continuous centerline.';return;end
% Always recompute physical edge lengths, rather than trusting pixel weights.
e=G.Edges.EndNodes;G.Edges.Weight=vecnorm((xy(e(:,1),:)-xy(e(:,2),:)).*scale,2,2);
bins=conncomp(G);lengths=accumarray(bins(e(:,1))',G.Edges.Weight,[max(bins) 1]);[~,largest]=max(lengths);
nodes=find(bins==largest);ends=nodes(degree(G,nodes)==1);
radius=bwdist(~padarray(logical(mask),[1 1],false));radius=radius(2:end-1,2:end-1)*min(spacing);
sample=interp2(radius,xy(:,1),xy(:,2),'nearest',0);
if isfield(network,'RootNode'),root=network.RootNode;
elseif isempty(ends),detail.Reason='Closed centerline has no proximal endpoint.';return;
else
 % Median proximal lumen over 5 mm reduces endpoint taper bias.
 merit=zeros(size(ends));
 for k=1:numel(ends),dist=distances(G,ends(k));merit(k)=median(sample(dist<=5));end
 [~,k]=max(merit);root=ends(k);
end
dist=distances(G,root);terminal=[];best=-Inf;
if isfield(network,'TerminalNode')
 terminal=network.TerminalNode;detail.AnatomyConfirmed=true;
else
 junctions=nodes(degree(G,nodes)>=3);
 for n=reshape(junctions,1,[])
  if dist(n)<5||~isfinite(dist(n)),continue;end
  neighborsN=neighbors(G,n);distal=neighborsN(dist(neighborsN)>dist(n)+eps);
  arms=[];
  for child=reshape(distal,1,[])
   % Cutting the junction excludes loops/projected shortcuts returning to it.
   cut=rmedge(G,n,neighborsN);reach=distances(cut,child);arm=max(reach(isfinite(reach)));
   arms(end+1)=arm; %#ok<AGROW>
  end
  arms=sort(arms,'descend');if numel(arms)<2||arms(2)<5,continue;end
  merit=sample(n)*min(arms(2),15)*min(dist(n)/15,1);
  if merit>best,best=merit;terminal=n;end
 end
end
if isempty(terminal),detail.Reason='No supported terminal bifurcation; manual AIF retained.';return;end
route=shortestpath(G,terminal,root);path=xy(route,:);s=[0;cumsum(vecnorm(diff(path).*scale,2,2))];
if numel(s)<2||s(end)<5,detail.Reason='Less than 5 mm of proximal centerline.';return;end
grid=(5:1:min(15,s(end)))';
if numel(grid)<2,detail.Reason='Insufficient proximal candidate interval.';return;end
ICA_candidate_centerline=interp1(s,path,grid);
detail.Available=true;detail.RootXY=xy(root,:);detail.TerminalXY=xy(terminal,:);
detail.DistanceFromTerminal_mm=grid;detail.ProximalPath=path;detail.Vessel='ICA candidate';
detail.Reason='Topology/diameter heuristic; C4-C5 unconfirmed; 5-15 mm PROXIMAL to inferred terminal ICA. Review projection overlaps.';
if detail.AnatomyConfirmed,detail.Reason='Reviewed terminal/root nodes; 5-15 mm proximal candidate interval; C4-C5 unconfirmed.';end
end
