classdef truckobj

%     fixed_var.diver_pay = [22.64 25.27]; fixed_var.petrol_price = 1.385; fixed_var.distance = 2.575; 
%     fixed_var.loading_time = duration([0 4 9]); fixed_var.unload_time = duration([0 1 5]);
%     truck_sch = truckobj(fixed_var);
    properties
        distance % 2.575
        loading_time %duration([0 4 9]);
        unload_time %duration([0 1 5]);
        payload_range = [135.3 211.4]
        num_trucks_range = [3 5]
        worker_cycle = duration([8 0 0])
        em_day_sp_range = [7.24 40.90]
        em_night_sp_range = [7.24 35.69]
        load_sp_range = [5.57 26.53]
        min_rest_time = duration([0 45 0])
        diver_pay_per_shift  %[22.64 25.27] * 8 %[day night] @US dollars
        petrol_price  % 1.385 - @US dollars per liter
        max_production
        obj_scale = [0.1 10000 3000]
    end
    
    methods
        function obj = truckobj(fixed_var)
            %fixed_var.diver_pay = [22.64 25.27]; fixed_var.petrol_price = 1.385; fixed_var.distance = 2.575;
            %fixed_var.loading_time = duration([0 4 9]); fixed_var.unload_time = duration([0 1 5]);
            obj.distance = fixed_var.distance;
            obj.loading_time = fixed_var.loading_time;
            obj.unload_time = fixed_var.unload_time;
            obj.petrol_price = fixed_var.petrol_price;
            obj.diver_pay_per_shift = fixed_var.diver_pay * hours(obj.worker_cycle);
            obj.max_production = obj.payload_range(2)*350;
        end
        
        function outputArg = objecitves(obj,PopDec)
            day_load_spd = (obj.load_sp_range(2)-obj.load_sp_range(1)) * PopDec(:,1) + obj.load_sp_range(1);
            day_empty_spd = (obj.em_day_sp_range(2)-obj.em_day_sp_range(1)) * PopDec(:,2) + obj.em_day_sp_range(1);
            night_load_spd = (obj.load_sp_range(2)-obj.load_sp_range(1)) * PopDec(:,3) + obj.load_sp_range(1);
            night_empty_spd = (obj.em_night_sp_range(2)-obj.em_night_sp_range(1)) * PopDec(:,4) + obj.em_night_sp_range(1);
            payload = (obj.payload_range(2)-obj.payload_range(1)) * PopDec(:,[5 6]) + obj.payload_range(1);
            num_trucks = round((obj.num_trucks_range(2)-obj.num_trucks_range(1)) * PopDec(:,[7 8]) + obj.num_trucks_range(1)); %[day night]
            time_state = round(PopDec(:,9));


            travel_em_time = obj.distance ./ [day_empty_spd night_empty_spd] * 60;
            travel_loaded_time = obj.distance ./ [day_load_spd night_load_spd] * 60;
            travel_time = travel_em_time + minutes(obj.loading_time) + travel_loaded_time + minutes(obj.unload_time);
            queue_time = minutes(obj.loading_time) - travel_time ./ num_trucks;
            queue_time(queue_time<0) = 0;
            cycle_time = travel_time + queue_time;

            shift_counts = floor(minutes(obj.worker_cycle-obj.min_rest_time) ./ cycle_time) .* num_trucks;
            shift_queue_time = (shift_counts-2*num_trucks) .* queue_time; %2 times truck starting
            total_queue_time = shift_queue_time(:,1)*2 + time_state .* shift_queue_time(:,2);
            counts = [shift_counts(:,1)*2 time_state .* shift_counts(:,2)];
            average_queue_time = total_queue_time ./ sum(counts,2);

            production = sum(counts .* payload, 2);
            production = obj.max_production - production;

            fuel_cost = sum(counts .* (0.0097 * payload + 3.65), 2);
            worker_pay = 2 * obj.diver_pay_per_shift(1) * num_trucks(:,1)  + time_state .* num_trucks(:,2) * obj.diver_pay_per_shift(2);
            total_cost = obj.petrol_price * fuel_cost + worker_pay;

            outputArg = [average_queue_time production total_cost] ./ obj.obj_scale;
        end
        
        function real_result = recover(obj,Obj,Dec)
            oper_range = [obj.load_sp_range; obj.em_day_sp_range; obj.load_sp_range; obj.em_night_sp_range; ...
                obj.payload_range; obj.payload_range; obj.num_trucks_range; obj.num_trucks_range];
            oper_scale = [oper_range(:,2)'-oper_range(:,1)' 1];
            oper_scale = repmat(oper_scale,size(Obj,1),1);
            oper_bias = [oper_range(:,1)' 0];
            oper_bias = repmat(oper_bias,size(Obj,1),1);

            real_oper = Dec .* oper_scale + oper_bias;
            real_oper(:,end-2:end) = round(real_oper(:,end-2:end));
            real_obj = Obj .* repmat(obj.obj_scale,size(Obj,1),1);
            real_obj(:,2) = obj.max_production - real_obj(:,2);

            travel_em_time = obj.distance ./ real_oper(:,[2,4]) * 60;
            travel_loaded_time = obj.distance ./ real_oper(:,[1,3]) * 60;
            travel_time = travel_em_time + minutes(obj.loading_time) + travel_loaded_time + minutes(obj.unload_time);
            queue_time = minutes(obj.loading_time) - travel_time ./ real_oper(:,[7,8]);
            queue_time(queue_time<0) = 0;
            cycle_time = travel_time + queue_time;
            rest_time = minutes(obj.min_rest_time) + mod(minutes(obj.worker_cycle-obj.min_rest_time), cycle_time);

            real_result = array2table([real_oper rest_time real_obj], 'VariableNames', {'day_loaded_speed','day_empty_speed',...
                'night_loaded_speed','night_empty_speed','day_payload','night_payload','day_truck_numbers','night_truck_numbers',...
                'work_shift_state','day_rest_time','night_rest_time','queuing_time','productions','cost'});

            real_result.day_rest_time = duration([zeros(size(Obj,1),1) real_result.day_rest_time zeros(size(Obj,1),1)]);
            real_result.night_rest_time = duration([zeros(size(Obj,1),1) real_result.night_rest_time.*real_result.work_shift_state zeros(size(Obj,1),1)]);
            real_result.queuing_time = duration([zeros(size(Obj,1),1) real_result.queuing_time zeros(size(Obj,1),1)]);
            real_result.night_loaded_speed = real_result.night_loaded_speed .* real_result.work_shift_state;
            real_result.night_empty_speed = real_result.night_empty_speed .* real_result.work_shift_state;
            real_result.night_payload = real_result.night_payload .* real_result.work_shift_state;
            real_result.night_truck_numbers = real_result.night_truck_numbers .* real_result.work_shift_state;
        end
        
        function [tline,back_time] = time_stamps(obj,result,shift,rest_t,back_t)
            if ~result.work_shift_state && strcmp(shift,'night')
                tline{1} = 'No night shift';
                return
            end
                
            tload = obj.loading_time; tunload = obj.unload_time;
            default_d = '15-Oct-2000 ';
            rest_t = datetime([default_d rest_t]);
            if exist('back_t','var')
                back_t = datetime([default_d back_t]);
            end
            switch shift
                case 'day'
                    t = datetime(string(datetime(rest_t,'Format','d-MMM-y'))+' 07:00:00');
                    end_t = datetime(string(datetime(rest_t,'Format','d-MMM-y'))+' 15:00:00');
                case 'afternoon'
                    t = datetime(string(datetime(rest_t,'Format','d-MMM-y'))+' 15:00:00');
                    end_t = datetime(string(datetime(rest_t,'Format','d-MMM-y'))+' 23:00:00');
                case 'night'
                    if rest_t>datetime(string(datetime(rest_t,'Format','d-MMM-y'))+' 23:00:00')
                        t = datetime(string(datetime(rest_t,'Format','d-MMM-y'))+' 23:00:00');
                        end_t = datetime(string(datetime(rest_t+1,'Format','d-MMM-y'))+' 07:00:00');
                    else
                        t = datetime(string(datetime(rest_t-1,'Format','d-MMM-y'))+' 23:00:00');
                        end_t = datetime(string(datetime(rest_t,'Format','d-MMM-y'))+' 07:00:00');
                    end
            end
            if ~(rest_t>t && rest_t<end_t)
                tline{1} = 'The resting clock time is incorrect.';
                tline{2} = ['The available time is from ' char(datetime(t,'Format','HH:mm:ss')) ' to ' char(datetime(end_t,'Format','HH:mm:ss'))];
                tline{3} = 'Please enter the correct resting time.';
                return;
            end
            
            if strcmp(shift,'night')
                t_m = duration([[0 obj.distance / result.night_empty_speed * 60 0]; [0 obj.distance / result.night_loaded_speed * 60 0]]);
                cycle_t = t_m(1) + tload + t_m(2) + tunload;
                queue_t = max(0,tload - cycle_t / result.night_truck_numbers);
            else
                t_m = duration([[0 obj.distance / result.day_empty_speed * 60 0]; [0 obj.distance / result.day_loaded_speed * 60 0]]);
                cycle_t = t_m(1) + tload + t_m(2) + tunload;
                queue_t = max(0,tload - cycle_t / result.day_truck_numbers);
            end
            cycle_t = cycle_t + queue_t;
            tline{1}=[char(datetime(t,'Format','HH:mm:ss')) '  Dispatching'];
            t=t+t_m(1); tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Loading']];
            t=t+tload; tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Transporting']];
            t=t+t_m(2); tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Unloading']];
            while t<rest_t
                t=t+tunload; tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Dispatching']];
                t=t+t_m(1);
                if queue_t>0
                    tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Queuing']]; t=t+queue_t;
                end
                tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Loading']];
                t=t+tload; tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Transporting']];
                t=t+t_m(2); tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Unloading']];
            end
            %n0 = nnz(cellfun(@isempty,tline));
            t=t+tunload; t_rest=t+obj.min_rest_time; t_remainder = mod(end_t+queue_t-t_rest,cycle_t);
            recom_rest = obj.min_rest_time + t_remainder;
            [h,m,s]=hms(recom_rest);
            tline=[tline ' ' [char(datetime(t,'Format','HH:mm:ss')) '  Resting'] ' '];
            if h>0
                tline=[tline 'Suggested resting time:']; tline=[tline ['45m to ' num2str(h) 'h' num2str(m) 'm' num2str(round(s)) 's'] ' '];
            else
                tline=[tline 'Suggested resting time:']; tline=[tline ['45m to ' num2str(m) 'm' num2str(round(s)) 's'] ' '];
            end
            if exist('back_t','var')&&(back_t-t>obj.min_rest_time)&&(back_t<t+recom_rest)
                t=back_t;
            else
                t=t+recom_rest;
            end
            back_time = char(datetime(t,'Format','HH:mm:ss'));
            tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Dispatching']];
            t=t+t_m(1); tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Loading']];
            t=t+tload; tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Transporting']];
            t=t+t_m(2); tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Unloading']];
            end_t = end_t - cycle_t;
            while t<end_t
                t=t+tunload; tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Dispatching']]; t=t+t_m(1);
                if queue_t>0
                    tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Queuing']]; t=t+queue_t;
                end
                tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Loading']];
                t=t+tload; tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Transporting']];
                t=t+t_m(2); tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Unloading']];
            end
            t=t+tunload; tline=[tline [char(datetime(t,'Format','HH:mm:ss')) '  Completed']];
        end
    end
end

