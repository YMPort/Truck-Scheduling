classdef truck < PROBLEM


    methods
        %% Default settings of the problem
        function Setting(obj)
            obj.M = 3;
            if isempty(obj.D); obj.D = 9; end
            obj.lower    = zeros(1,obj.D);
            obj.upper    = ones(1,obj.D);
            obj.encoding = 'real';
            obj.maxFE = 500;
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            truck_sch=obj.parameter{1};
            PopObj = truck_sch.objecitves(PopDec);
%             PopObj = truck_obj(PopDec);
        end
    end
end