%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   MoveJ:
%   Caution. The global variable robot should be loaded
%   with a valid robot arm.
%   Example: MoveJ(pos_b_rec, 'v1000', 'z100', gripper, wobj0);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Copyright (C) 2012, by Arturo Gil Aparicio
%
% This file is part of ARTE (A Robotics Toolbox for Education).
% 
% ARTE is free software: you can redistribute it and/or modify
% it under the terms of the GNU Lesser General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% ARTE is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Lesser General Public License for more details.
% 
% You should have received a copy of the GNU Leser General Public License
% along with ARTE.  If not, see <http://www.gnu.org/licenses/>.
function MoveJ(robtarget, speeddata, zonedata, gripper, Wobj)

global configuration robot

fprintf('\nCall to MoveJ');

%obtain current joint coordinates
q_current = robot.q;

%Ttool, transformation from the robot's end to the TCP
Ttool = transform_to_homogeneous(gripper(2:end));

%compute target joint coordinates, from the inverse kinematics
%select desired joint values by using conf data from robtarget
%select configuration
conf = get_conf_data(robtarget);
Ttotal = transform_to_homogeneous(robtarget);

%T = Ttotal*inv(Ttool);
T = Ttotal/Ttool;

%Obtain solutions from inversekinematic function
q_final=inversekinematic(robot, T, robot.q);

%select one of the solutions of the inverse kinematic problem
% solution according to configuration and language.
% The conf vector defines the quadrants of the joints [theta1 theta4 theta6 thetax]
% =[cf1 cf4 cf6 cfx]. Where the x angle is zero in this implementation.
q_final=select_configuration(robot, q_final, conf);
%(q_final*180/pi)'

speed = obtain_joint_speed(robot, speeddata);
%when fine is specified, the radius is zero, otherwise, 
%the radius represents a sphere around the target where the
%movement is changed to the next target
radius = obtain_zone_data(zonedata);

%find time to perform movement
[actual_speed, tmax]=synchronize(q_current, q_final, speed, robot.accelmax);

%in this case, if the total time for the movement is lower than the
%configuration.delta_time time then 10 points are interpolated
if tmax <= configuration.delta_time
    t = [0:tmax/10:tmax]';
else
    %local time for the planning, normal case
    t = [0:configuration.delta_time:tmax]';
end

if radius==0
    %compute a smooth trajectory in q and qd
    %in this case, the final speed is zero
    [q, qd, qdd] = compute_joint_trajectory_indep(robot, q_current, q_final, robot.qd, zeros(1,robot.DOF), t);
else
    %in this case, the final speed is selected as the speed selected by the
    %variable speeddata
    [q, qd, qdd] = compute_joint_trajectory_indep(robot, q_current, q_final, robot.qd, actual_speed, t);
end
%finds the first joint coordinates that are inside a radius r of the target
%point
index = find_first_in_zone_data(robot, q, T, radius);

%the robot performs the movement until the index found. The coordinates, joint speed and acceleratin
%are stored and used in the planning of the next point
robot.q=q(:,index);
robot.qd=qd(:,index);
robot.qdd=qdd(:,index);

%store all the trajectory for plotting
%the joint trajectories, speeds and acceleration of susequent movements are
%store here
%robot.q_vector=[robot.q_vector q(:, 1:index)];
%robot.qd_vector=[robot.qd_vector qd(:, 1:index)];
%robot.qdd_vector=[robot.qdd_vector qdd(:, 1:index)];

robot.q_vector = q(:, 1:index);
robot.qd_vector = qd(:, 1:index);
robot.qdd_vector = qdd(:, 1:index);

%a global time for the planning is computed.
%in this way, the total trajectory of different movements can be plotted
if length(robot.time)==0
    tend = 0;
else
    tend = robot.time(end);
end
t = t + tend;
%store total time
robot.time=t(1:index)';

%Test whether there are joints outside mechanical limits
test_joint_limits(robot);

%Plot position, velocity and acceleration
%plot_joint_data(robot);
%Now, animate the robot in 3D
animate(robot, q);

%Plot the trajectory
pp = zeros(3,size(q,2));
for i=1:size(q,2),
    T=directkinematic(robot, q(:,i));
    %pp=[pp T(1:3,4)];
    pp(1:3,i)=T(1:3,4);
end
plot3(pp(1,:),pp(2,:),pp(3,:), 'k', 'LineWidth', 2)









