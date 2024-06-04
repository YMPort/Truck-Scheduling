function plotobj(result)

ini = result{1,2}.objs;
ind = randi([1 100],1,5);
plot3(ini(ind,1),ini(ind,2),ini(ind,3),'go')
hold on

ini = result{3,2}.objs;
%ind = randi([1 100],1,10);
plot3(ini(ind,1),ini(ind,2),ini(ind,3),'bo')

ini = result{5,2}.objs;
%ind = randi([1 100],1,10);
plot3(ini(ind,1),ini(ind,2),ini(ind,3),'ro')