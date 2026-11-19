function RedCap_EnvSim(mode)
%REDCAP_ENVSIM  Environment-coupled energy model for 5G RedCap / eRedCap.
%
%   RedCap_EnvSim            runs the complete experiment set used in the
%                            report (10 paired seeds, all sweeps, all figures)
%   RedCap_EnvSim('quick')   short run for a first check (2 seeds, small sweeps)
%   RedCap_EnvSim('day')     daily comparison only
%   RedCap_EnvSim('figs')    redraw figures from results/*.csv
%   RedCap_EnvSim('openloop') rerun the fixed-20-dBm sensitivity only
%
%   The model is deliberately self-contained: no toolbox, no data files, and
%   no random numbers outside the seeded generator.  Every parameter lives in
%   CFG_DEFAULT so that a marker can trace a number back to its source.
%
%   Outputs
%     results/table3_day.csv          daily energy / battery / deadline table
%     results/table4_sinr.csv         energy and miss rate versus SINR
%     results/table5_load.csv         deadline miss versus offered load
%     results/table_temp.csv          battery life versus ambient temperature
%     results/table_openloop.csv      fixed-20-dBm sensitivity
%     figures/fig2_environment.png
%     figures/fig3_day.png
%     figures/fig4_sweeps.png
%     figures/fig5_temperature.png
%     figures/fig6_rain.png
%     figures/fig7_openloop.png
%
%   See README.md for the mapping between equations (1)-(8) in the report and
%   the functions below.

if nargin < 1 || isempty(mode), mode = 'all'; end
mode = lower(string(mode));

here    = fileparts(mfilename('fullpath'));
root    = fileparts(here);
resdir  = fullfile(root,'results');
figdir  = fullfile(root,'figures');
if ~exist(resdir,'dir'), mkdir(resdir); end
if ~exist(figdir,'dir'), mkdir(figdir); end

cfg = cfg_default();
cfg.root = root; cfg.resdir = resdir; cfg.figdir = figdir;

switch mode
    case "quick"
        cfg.nSeeds       = 2;
        cfg.tempSeeds    = 2;
        cfg.loadSeeds    = 2;
        cfg.loadSlots    = 900;
        cfg.sinrSeeds    = 2;
        cfg.sinrSlots    = 900;
        cfg.makeFigures  = true;
        run_all(cfg);
    case "day"
        cfg.nSeeds = 5; cfg.makeFigures = true;
        run_day_experiment(cfg);
        draw_environment(cfg);
        draw_day(cfg);
    case {"figs","plots"}
        draw_environment(cfg);
        draw_rain(cfg);
        draw_day(cfg);
        loadtab = readtable(fullfile(cfg.resdir,'table5_load.csv'));
        sinrtab = readtable(fullfile(cfg.resdir,'table4_sinr.csv'));
        temptab = readtable(fullfile(cfg.resdir,'table_temp.csv'));
        opentab = readtable(fullfile(cfg.resdir,'table_openloop.csv'));
        draw_sweeps(cfg,loadtab,sinrtab);
        draw_temperature(cfg,temptab);
        draw_openloop(cfg,opentab);
    case "openloop"
        tab = run_openloop_experiment(cfg);
        draw_openloop(cfg,tab);
    otherwise
        cfg.makeFigures = true;
        run_all(cfg);
end
end

% =====================================================================
%  DRIVER
% =====================================================================
function run_all(cfg)
fprintf('\n=== EEEN3008J Topic 08: RedCap bandwidth versus battery cost ===\n');
fprintf('MATLAB %s | %d paired seeds | %d slots/day | dt = %.0f s\n', ...
    version, cfg.nSeeds, cfg.K, cfg.dt);

selfcheck(cfg);
draw_environment(cfg);
draw_rain(cfg);

run_day_experiment(cfg);
loadtab = run_load_experiment(cfg);
sinrtab = run_sinr_experiment(cfg);
temptab = run_temperature_experiment(cfg);
opentab = run_openloop_experiment(cfg);

if cfg.makeFigures
    draw_day(cfg);
    draw_sweeps(cfg, loadtab, sinrtab);
    draw_temperature(cfg, temptab);
    draw_openloop(cfg, opentab);
end

fprintf('\nAll results written to %s\n', cfg.resdir);
fprintf('All figures written to %s\n', cfg.figdir);
end

% =====================================================================
%  PARAMETERS  (Table 2 of the report)
% =====================================================================
function cfg = cfg_default()
cfg.dt          = 10;              % slot length [s]
cfg.K           = 8640;            % 24 h / 10 s
cfg.fc          = 3500;            % carrier [MHz], band n78
cfg.Bset        = [5 20 100];      % bandwidths [MHz]
cfg.dist_km     = 0.600;           % terminal distance [km]
cfg.foliage_m   = 8;               % vegetation depth [m]
cfg.h_bs        = 25;              % base-station height [m] (for reporting)
cfg.h_ue        = 1.5;             % terminal height [m]
cfg.Gb          = 15;              % base-station antenna gain [dBi]
cfg.Gu          = 0;               % terminal antenna gain [dBi]
cfg.Lbody       = 3;               % body / installation loss [dB]
cfg.NF          = 7;               % receiver noise figure [dB]
cfg.shadow_sigma= 6;               % log-normal shadowing [dB]
cfg.shadow_block= 60;              % 10 min correlation block [slots]
cfg.sinr_target = 10;              % closed-loop target [dB]
cfg.sinr_floor  = -6;              % SE = 0 below this SINR [dB]
cfg.Pmax        = 23;              % maximum transmit power [dBm]
cfg.Pmin        = -10;             % minimum transmit power [dBm]
cfg.Ptx_fixed   = 20;              % open-loop sensitivity [dBm]
cfg.gap         = 0.75;            % Shannon gap factor
cfg.snr_gap     = 1.585;           % 2 dB gap inside log2(1+SINR/G)
cfg.se_max      = 5.55;            % 64-QAM cap [bit/s/Hz]
cfg.sched_eff   = [0.42 0.45 0.50]; % scheduled fraction, one value per B
cfg.penalty100  = 6;               % wideband implementation margin [dB]
cfg.t_proc      = 2e-3;            % baseband processing per packet [s]
cfg.E_switch    = 0.15e-3;         % BWP retune energy [J]
cfg.t_switch    = 2e-3;            % BWP retune gap [s]
cfg.dwell_slots = 720;             % 2 h minimum dwell for adaptive policy
cfg.min_sinr_choice = 0;           % do not select a BWP below this SINR [dB]
cfg.L_tel       = 2*1024*8;        % 2 kB telemetry [bit]
cfg.sig_tel     = 0.25;            % log-normal packet-size sigma
cfg.D_tel       = 0.100;           % telemetry deadline [s]
cfg.L_img       = 1*1024*1024*8;   % 1 MB image [bit]
cfg.D_img       = 10;              % image deadline [s]
cfg.img_start   = 8*3600;          % 08:00
cfg.img_stop    = 18*3600;         % 18:00
cfg.img_period  = 300;             % every 5 min
cfg.C_nom       = 37*3600;         % 37 Wh [J]
cfg.V_nom       = 3.7;             % nominal battery voltage [V]
cfg.R_int       = 0.15;            % internal resistance at 25 C [ohm]
cfg.k_self      = 0.02/30;         % 2 %/month at 25 C [1/day]
cfg.nSeeds      = 10;
cfg.tempSeeds   = 1;
cfg.loadSeeds   = 2;
cfg.loadSlots   = 1200;
cfg.sinrSeeds   = 2;
cfg.sinrSlots   = 1200;
cfg.loads_kbps  = [50 100 200 400 800 1600 3200 6400];
cfg.sinrs_dB    = [-4 0 4 8 12 16 20];
cfg.temps_C     = [-10 -5 0 5 10 15 20 25 30 35 40 45];
cfg.makeFigures = true;
end

function n = poisson_rng(lambda)
% Poisson random number without the Statistics Toolbox.
if lambda <= 0, n = 0; return; end
if lambda < 30
    L = exp(-lambda); k = 0; p = 1;
    while p > L
        k = k + 1; p = p*rand;
    end
    n = k - 1;
else
    n = max(0, round(lambda + sqrt(lambda)*randn));
end
end

% =====================================================================
%  ENVIRONMENT  (Section 4.5, Figure 2)
% =====================================================================
function env = build_environment(cfg, seed)
K  = cfg.K; dt = cfg.dt;
h  = ((0:K-1)'*dt + dt/2)/3600;          % hour of day at slot centre
rng(1000 + 37*seed, 'twister');

% --- air temperature and humidity: min 03:00, max 15:00 -------------
env.T  = 21 + 9*cos(2*pi*(h-15)/24);                 % 12 ... 30 C
env.RH = 72 - 24*cos(2*pi*(h-15)/24);                % 48 ... 96 %
env.h  = h;

% --- rain: a two-hour cell around 14:00, peak 45 mm/h ---------------
env.rain = 45*exp(-((h-14)/0.55).^2);

% --- wet foliage: dry Weissberger plus a wet-leaf excess -------------
f = cfg.fc;
dry_veg = 0.34 * f^0.39 * cfg.foliage_m^0.25;         % about 13.7 dB
wet     = min(1,max(0,env.rain/20 + max(0,env.RH-80)/20));
env.Lveg = dry_veg + 5.0*wet;                         % 13.7 ... 18.7 dB

% --- rain specific attenuation, alpha = 1 for a compact model --------
k_rain = 0.0009;                                     % dB/km per mm/h at 3.5 GHz
env.Lrain = k_rain * env.rain * cfg.dist_km;          % ~0.02 dB at peak

% --- traffic and sharing profile ------------------------------------
dayUp   = 0.5*(1+tanh((h-6.5)/1.3));
dayDown = 0.5*(1+tanh((21.5-h)/1.3));
day     = dayUp .* dayDown;
lunch   = 1 - 0.30*exp(-((h-12.5)/0.55).^2);
act     = day .* lunch;
env.act    = act;
env.users  = max(4, min(20, round(4 + 16*act)));
env.lambda = 0.60 + 2.25*act;                         % packets/s
env.load_kbps = env.lambda*cfg.L_tel/1000 + ...
    (h>=cfg.img_start/3600 & h<cfg.img_stop/3600)*cfg.L_img/1000/cfg.img_period;

% --- interference: 6 dB daytime rise --------------------------------
env.I = 6*act;

% --- shadowing: independent 10-minute blocks ------------------------
nblk  = ceil(K/cfg.shadow_block);
sb    = cfg.shadow_sigma*randn(nblk,1);
env.shadow = repelem(sb, cfg.shadow_block);
env.shadow = env.shadow(1:K);

% --- path loss, equation (1) ----------------------------------------
env.PL = 32.44 + 20*log10(cfg.dist_km) + 20*log10(cfg.fc) + ...
         env.Lveg + env.Lrain + cfg.Lbody + env.shadow;
env.seed = seed;
end

function arr = build_arrivals(cfg, env, seed)
% Packet arrivals are generated once per seed and shared by every policy.
rng(5000 + 91*seed, 'twister');
K = cfg.K; dt = cfg.dt;

tcell = cell(K,1); Lcell = cell(K,1); dcell = cell(K,1); icell = cell(K,1);
for k = 1:K
    n = poisson_rng(env.lambda(k)*dt);
    if n > 0
        ta = (k-1)*dt + dt*rand(n,1);
        L  = cfg.L_tel * exp(cfg.sig_tel*randn(n,1) - 0.5*cfg.sig_tel^2);
        tcell{k} = ta; Lcell{k} = L;
        dcell{k} = ta + cfg.D_tel;
        icell{k} = false(n,1);
    end
end

% One image every five minutes between 08:00 and 18:00.
ti = (cfg.img_start:cfg.img_period:(cfg.img_stop-1))';
ni = numel(ti);
if ni > 0
    kk = min(K, floor(ti/dt)+1);
    for j = 1:ni
        tcell{kk(j)}(end+1,1) = ti(j);
        Lcell{kk(j)}(end+1,1) = cfg.L_img;
        dcell{kk(j)}(end+1,1) = ti(j) + cfg.D_img;
        icell{kk(j)}(end+1,1) = true;
    end
end

arr.t     = vertcat(tcell{:});
arr.bits  = vertcat(Lcell{:});
arr.dead  = vertcat(dcell{:});
arr.isimg = vertcat(icell{:});
[arr.t, idx] = sort(arr.t);
arr.bits = arr.bits(idx); arr.dead = arr.dead(idx); arr.isimg = arr.isimg(idx);
arr.n = numel(arr.t);
end

% =====================================================================
%  LINK AND POWER  (Sections 4.1-4.2, equations (1)-(5))
% =====================================================================
function [sinr, se, rate, ptx] = link_eval(cfg, B, env, k, pcontrol)
PL = env.PL(k);
N  = -174 + 10*log10(B*1e6) + cfg.NF + ...
     10*log10((env.T(k)+273)/290) + env.I(k);

if pcontrol
    ptx = cfg.sinr_target + N + PL - cfg.Gb - cfg.Gu;
    ptx = min(cfg.Pmax, max(cfg.Pmin, ptx));
else
    ptx = cfg.Ptx_fixed;
end
sinr = ptx - PL + cfg.Gb + cfg.Gu - N - cfg.penalty100*(B==100);

if sinr < cfg.sinr_floor
    se = 0;
else
    se = min(cfg.se_max, cfg.gap*log2(1 + 10^(sinr/10)/cfg.snr_gap));
end
rate = B*1e6 * se / env.users(k) * cfg.sched_eff(cfg.Bset==B);
end

function [Pdev, Pidle, eta, Pc] = device_power(cfg, B, T, RH, ptx)
% Equation (4) and (5).  Powers in mW, ptx in dBm.
Pc = 91.7 * 2^((T-25)/25) + 19.76 * B^0.7;
eta = max(0.12, 0.35*(1 - 0.0035*max(0,T-25)));
Ptx_dc = 10^(ptx/10) / eta;
heat = 0;
if T < 5 && RH > 85
    heat = 60*0.25;                    % 60 mW heater at 25 % duty
end
Pdev = Pc + Ptx_dc + heat;
Pidle = 1.0 + 8.5*B^0.3;
end

function [life, fC, kSD] = battery_life(cfg, Eday, T)
% Equation (7).  Capacity derating, self-discharge and I2R loss.
Tv = [-20 -10 0 25 45];
fv = [0.55 0.68 0.85 1.00 0.93];
fC = interp1(Tv, fv, T, 'linear', 'extrap');
fC = min(1.0, max(0.40, fC));
kSD = cfg.k_self * 2^((T-25)/10);       % per day
% I2R loss at the nominal rail, from the average load
Pavg = Eday/86400;                       % W
I = Pavg/cfg.V_nom;
R = cfg.R_int*(1 + 0.02*(25-T));
Eday = Eday + I^2*R*86400;
life = cfg.C_nom*fC/(Eday + cfg.C_nom*kSD);
end

% =====================================================================
%  ONE DAY, ONE POLICY
% =====================================================================
function [m, tr] = simulate_day(cfg, env, arr, pol)
K = cfg.K; dt = cfg.dt;
cap = arr.n + 200;
qt = zeros(cap,1); qb = zeros(cap,1); qd = zeros(cap,1); qi = false(cap,1);
head = 1; tail = 0; ptr = 1;

Eday = 0; delivered = 0; miss = 0; switches = 0;
lastB = pol.B; Bhist = zeros(K,1); Pavg = zeros(K,1); Qhist = zeros(K,1);
lastSwitch = 1; lam_hat = 0.60;   % recent arrival-rate estimate [packets/s]
SinrHist = zeros(K,1); RateHist = zeros(K,1); BusyHist = zeros(K,1);
Eslot = zeros(K,1);

for k = 1:K
    t0 = (k-1)*dt; t1 = k*dt;

    % ---- arrivals ---------------------------------------------------
    ptr_before = ptr;
    while ptr <= arr.n && arr.t(ptr) < t1
        tail = tail + 1;
        qt(tail) = arr.t(ptr); qb(tail) = arr.bits(ptr);
        qd(tail) = arr.dead(ptr); qi(tail) = arr.isimg(ptr);
        ptr = ptr + 1;
    end

    % ---- discard packets that are already stale ---------------------
    while head <= tail && qd(head) < t0
        miss = miss + 1; head = head + 1;
    end

    % ---- bandwidth choice ------------------------------------------
    B = lastB;
    if isempty(pol.type) || strcmp(pol.type,'fixed')
        B = pol.B;
    else
        if strcmp(pol.type,'adaptive') && (k - lastSwitch) < cfg.dwell_slots
            B = lastB;                       % minimum dwell time
        else
            qbits = sum(qb(head:tail));
            if strcmp(pol.type,'genie')
                B = choose_bw(cfg, B, qbits, env, k, true, lam_hat);
            else
                B = choose_bw(cfg, B, qbits, env, k, false, lam_hat);
            end
        end
    end
    switched_now = (B ~= lastB) && (k > 1);
    if switched_now
        switches = switches + 1; lastB = B; lastSwitch = k;
    end

    % ---- link -------------------------------------------------------
    [sinr, ~, rate, ptx] = link_eval(cfg, B, env, k, pol.pcontrol);
    [Pdev, Pidle] = device_power(cfg, B, env.T(k), env.RH(k), ptx);

    % ---- service ----------------------------------------------------
    avail = dt;
    Esw = 0;
    if switched_now
        avail = dt - cfg.t_switch;
        Esw = cfg.E_switch;
    end
    busy = 0; delivered_slot = 0;
    tstart = t0 + (switched_now)*cfg.t_switch;
    tend   = t0 + dt;
    while head <= tail && busy < avail - 1e-12
        rem = qb(head);
        s = rem/rate;
        wall = max(tstart + busy, qt(head));  % retune gap, then arrival
        % Earliest possible completion misses the deadline: drop now.
        if wall + s > qd(head) + 1e-12
            miss = miss + 1; head = head + 1; continue;
        end
        if wall + s <= tend
            busy = busy + s;
            delivered_slot = delivered_slot + rem;
            head = head + 1;
        else
            frac = (tend - wall)/s;
            qb(head) = rem*(1-frac);
            delivered_slot = delivered_slot + rem*frac;
            busy = busy + (tend - wall);
            break;
        end
    end

    E = Pdev*busy + Pidle*(dt-busy) + Esw;   % mW*s = mJ
    Eday = Eday + E; delivered = delivered + delivered_slot;
    Eslot(k) = E; Pavg(k) = E/dt; Bhist(k) = B;
    Qhist(k) = sum(qb(head:tail))/8;          % bytes
    n_new = ptr - ptr_before;
    lam_hat = 0.80*lam_hat + 0.20*(n_new/dt);  % exponential average
    SinrHist(k) = sinr; RateHist(k) = rate; BusyHist(k) = busy;
end

% packets left in the buffer at midnight are undelivered
miss = miss + (tail-head+1);

m.policy = pol.name;
m.B = pol.B;
m.Eday = Eday/1000;                 % mJ -> J
m.delivered = delivered;
m.goodput_kbps = delivered/86400/1000;
m.Eperbit_nJ = NaN;
idleE = 0;
for k = 1:K
    Bk = Bhist(k);
    idleE = idleE + (1.0 + 8.5*Bk^0.3)*dt;   % mJ
end
m.radioE = (Eday - idleE)/1000;     % J, excludes eDRX floor
if delivered > 0
    m.Eperbit_nJ = m.radioE/delivered*1e9;
end
m.miss_pct = 100*miss/max(1,arr.n);
m.switches = switches;
m.Pavg_mW = Eday/86400;             % mJ/s = mW
[m.life, ~, ~] = battery_life(cfg, m.Eday, mean(env.T));

tr.Pavg = Pavg; tr.B = Bhist; tr.Q = Qhist; tr.sinr = SinrHist;
tr.rate = RateHist; tr.busy = BusyHist; tr.Eslot = Eslot;
end

function B = choose_bw(cfg, Bprev, qbits, env, k, genie, lam_hat)
% Equation (8), with a 5 % hysteresis preference for the current BWP.
Bs = cfg.Bset;
if ~genie
    Bs = Bs(Bs <= 20);      % a RedCap terminal cannot select the 100 MHz mode
end
cost = inf(size(Bs)); ratev = zeros(size(Bs));
for j = 1:numel(Bs)
    B = Bs(j);
    kk = k; if ~genie, kk = max(1,k-1); end
    [sinrj,~,ratev(j),ptx] = link_eval(cfg, B, env, kk, true);
    if ratev(j) <= 0 || sinrj < cfg.min_sinr_choice
        ratev(j) = 0;
        continue;
    end
    b = max(qbits + cfg.L_tel, ...
        (lam_hat*cfg.dt + 2*sqrt(lam_hat*cfg.dt))*cfg.L_tel);
    tsrv = min(cfg.dt, b/ratev(j));
    [Pdev, Pidle] = device_power(cfg, B, env.T(k), env.RH(k), ptx);
    c = (Pdev*tsrv + Pidle*(cfg.dt-tsrv))/b;
    if B == Bprev, c = 0.95*c; end
    cost(j) = c;
end
if all(ratev <= 0)
    B = Bprev; return;
end
feas = (qbits + cfg.L_tel)./max(ratev,eps) + cfg.t_proc <= cfg.D_tel;
if any(feas)
    c = cost; c(~feas) = inf;
    [~,j] = min(c);
else
    % no candidate meets the 100 ms deadline: stay within 10 % of the
    % fastest drain rate, then choose the cheapest of those.
    rmax = max(ratev);
    ok = ratev >= 0.90*rmax;
    c = cost; c(~ok) = inf;
    [~,j] = min(c);
end
B = Bs(j);
end

% =====================================================================
%  DAY EXPERIMENT  (Table 3, Figures 3-4c)
% =====================================================================
function day = run_day_experiment(cfg)
pols = make_policies();
nP = numel(pols); nS = cfg.nSeeds;
E = nan(nS,nP); EB = nan(nS,nP); L = nan(nS,nP);
M = nan(nS,nP); S = nan(nS,nP); G = nan(nS,nP);
traces = struct('Pavg',{},'B',{},'Q',{},'sinr',{},'rate',{},'busy',{},'Eslot',{});
for s = 1:nS
    env = build_environment(cfg,s);
    arr = build_arrivals(cfg,env,s);
    fprintf('  day seed %2d/%2d: %6d packets\n', s, nS, arr.n);
    for p = 1:nP
        [m,tr] = simulate_day(cfg,env,arr,pols(p));
        E(s,p)=m.Eday; EB(s,p)=m.Eperbit_nJ; L(s,p)=m.life;
        M(s,p)=m.miss_pct; S(s,p)=m.switches; G(s,p)=m.goodput_kbps;
        if s==1, traces(p) = tr; end
    end
end

day.names = {pols.name}';
day.E = E; day.EB = EB; day.life = L; day.miss = M; day.sw = S; day.good = G;
day.mean = mean(E,1); day.ci = 1.96*std(E,0,1)/sqrt(nS);
day.EBmean = mean(EB,1); day.lifemean = mean(L,1); day.missmean = mean(M,1);
day.swmean = mean(S,1); day.goodmean = mean(G,1);

T = table(day.names, day.mean', day.ci', day.EBmean', day.lifemean', ...
    day.missmean', day.swmean', day.goodmean', ...
    'VariableNames', {'Policy','DailyEnergy_J','CI95_J','EnergyPerBit_nJ', ...
    'BatteryLife_days','DeadlineMiss_pct','Switches_per_day','Goodput_kbps'});
writetable(T, fullfile(cfg.resdir,'table3_day.csv'));
disp(T);

save(fullfile(cfg.resdir,'day_traces.mat'),'traces');
day.traces = traces;
end

function pols = make_policies()
pols = struct('name',{},'B',{},'type',{},'pcontrol',{});
pols(end+1) = struct('name','Fixed 5 MHz (eRedCap)','B',5,'type','fixed','pcontrol',true);
pols(end+1) = struct('name','Fixed 20 MHz (RedCap)','B',20,'type','fixed','pcontrol',true);
pols(end+1) = struct('name','Fixed 100 MHz (NR-wide)','B',100,'type','fixed','pcontrol',true);
pols(end+1) = struct('name','Adaptive (proposed)','B',20,'type','adaptive','pcontrol',true);
pols(end+1) = struct('name','Genie bound','B',20,'type','genie','pcontrol',true);
end

% =====================================================================
%  LOAD AND SINR SWEEPS  (Tables 4-5, Figure 4)
% =====================================================================
function tab = run_load_experiment(cfg)
% Fixed received power (equivalently, fixed total transmit power): the SINR
% of a B-MHz receiver is SINR20 - 10log10(B/20).  This is the main comparison
% requested by the topic brief.
rows = {};
for sinr20 = [15 0]
    for load = cfg.loads_kbps
        for B = cfg.Bset
            ms = nan(cfg.loadSeeds,1); es = nan(cfg.loadSeeds,1);
            for s = 1:cfg.loadSeeds
                [m,~] = steady_state(cfg,B,load,sinr20,s);
                ms(s)=m.miss_pct; es(s)=m.Eperbit_nJ;
            end
            rows(end+1,:) = {sinr20,load,B,mean(ms),mean(es)}; %#ok<AGROW>
        end
    end
end
tab = cell2table(rows,'VariableNames',{'SINR20_dB','Load_kbps','B_MHz','Miss_pct','Eperbit_nJ'});
writetable(tab,fullfile(cfg.resdir,'table5_load.csv'));

% compact report-style matrices
fprintf('\nDeadline miss [%%], SINR20 = 15 dB\n');
fprintf('%10s','Load:'); fprintf('%9d',cfg.loads_kbps); fprintf('\n');
for B = cfg.Bset
    r = tab(tab.SINR20_dB==15 & tab.B_MHz==B,:);
    fprintf('%7d MHz',B); fprintf('%9.3f',r.Miss_pct); fprintf('\n');
end
end

function tab = run_sinr_experiment(cfg)
rows = {};
for sinr20 = cfg.sinrs_dB
    for B = cfg.Bset
        ms = nan(cfg.sinrSeeds,1); es = nan(cfg.sinrSeeds,1);
        for s = 1:cfg.sinrSeeds
            [m,~] = steady_state(cfg,B,100,sinr20,s);
            ms(s)=m.miss_pct; es(s)=m.Eperbit_nJ;
        end
        rows(end+1,:) = {sinr20,B,mean(ms),mean(es)}; %#ok<AGROW>
    end
end
tab = cell2table(rows,'VariableNames',{'SINR20_dB','B_MHz','Miss_pct','Eperbit_nJ'});
writetable(tab,fullfile(cfg.resdir,'table4_sinr.csv'));

fprintf('\nEnergy per delivered bit [nJ], 100 kbit/s\n');
fprintf('%10s','SINR:'); fprintf('%9d',cfg.sinrs_dB); fprintf('\n');
for B = cfg.Bset
    r = tab(tab.B_MHz==B,:);
    fprintf('%7d MHz',B); fprintf('%9.0f',r.Eperbit_nJ); fprintf('\n');
end
end

function [m, tr] = steady_state(cfg, B, load_kbps, sinr20, seed)
% Constant-channel queueing run.  No weather, no images: this isolates the
% bandwidth/load/SINR trade-off of Tables 4 and 5.
rng(7000 + 13*seed + B + round(10*sinr20), 'twister');
nSlots = cfg.loadSlots; dt = cfg.dt;
T = 25; RH = 50; users = 20;

sinr = sinr20 - 10*log10(B/20) - cfg.penalty100*(B==100);
if sinr < cfg.sinr_floor
    se = 0;
else
    se = min(cfg.se_max, cfg.gap*log2(1 + 10^(sinr/10)/cfg.snr_gap));
end
rate = B*1e6*se/users*cfg.sched_eff(cfg.Bset==B);
% Transmit power that gives the requested 20-MHz SINR at a 110 dB link.
PLref = 110;
N20 = -174 + 10*log10(20e6) + cfg.NF;
ptx = sinr20 + N20 + PLref - cfg.Gb - cfg.Gu;
ptx = min(cfg.Pmax, max(cfg.Pmin, ptx));
[Pdev,Pidle] = device_power(cfg,B,T,RH,ptx);

lambda = load_kbps*1000/cfg.L_tel;       % packets/s
nArr = poisson_rng(lambda*nSlots*dt);
if nArr < 1, nArr = 1; end
ta = sort(nSlots*dt*rand(nArr,1));
L  = cfg.L_tel*exp(cfg.sig_tel*randn(nArr,1) - 0.5*cfg.sig_tel^2);
dl = ta + cfg.D_tel;

cap = nArr+10; qb=zeros(cap,1); qd=zeros(cap,1); head=1; tail=0; ptr=1;
busyTot=0; delivered=0; miss=0;
for k=1:nSlots
    t0=(k-1)*dt; t1=k*dt;
    while ptr<=nArr && ta(ptr)<t1
        tail=tail+1; qb(tail)=L(ptr); qd(tail)=dl(ptr); ptr=ptr+1;
    end
    while head<=tail && qd(head)<t0
        miss=miss+1; head=head+1;
    end
    busy=0;
    while head<=tail && busy<dt-1e-12
        if rate<=0, break; end
        s=qb(head)/rate;
        if t0+busy+s > qd(head)+1e-12
            miss=miss+1; head=head+1; continue;
        end
        if busy+s<=dt
            busy=busy+s; delivered=delivered+qb(head); head=head+1;
        else
            rem0=qb(head); frac=(dt-busy)/s;
            delivered=delivered+rem0*frac;
            qb(head)=rem0*(1-frac); busy=dt; break;
        end
    end
    busyTot=busyTot+busy;
end
miss=miss+(tail-head+1);
EdayLike = Pdev*busyTot + Pidle*(nSlots*dt-busyTot);   % mJ
m.miss_pct = 100*miss/max(1,nArr);
if delivered > 0
    m.Eperbit_nJ = (EdayLike - Pidle*nSlots*dt)/1000/delivered*1e9;
else
    m.Eperbit_nJ = NaN;
end
m.rate_Mbps = rate/1e6;
m.Pdev_mW = Pdev;
tr.rate = rate;
end

% =====================================================================
%  TEMPERATURE AND OPEN-LOOP  (Figures 5 and 7)
% =====================================================================
function tab = run_temperature_experiment(cfg)
pols = make_policies(); nP = numel(pols);
rows = {};
for T = cfg.temps_C
    for p = 1:nP
        es = nan(cfg.tempSeeds,1); ls = nan(cfg.tempSeeds,1);
        for s = 1:cfg.tempSeeds
            [m,~] = day_at_temperature(cfg,T,s,pols(p));
            es(s)=m.Eperbit_nJ; ls(s)=m.life;
        end
        rows(end+1,:) = {T,pols(p).name,mean(es),mean(ls)}; %#ok<AGROW>
    end
end
tab = cell2table(rows,'VariableNames',{'T_C','Policy','Eperbit_nJ','BatteryLife_days'});
writetable(tab,fullfile(cfg.resdir,'table_temp.csv'));
end

function [m,tr] = day_at_temperature(cfg,T,seed,pol)
% Same traffic and link, but the air temperature is held constant.  This is
% the controlled thermal sweep of Figure 5; the 24 h profile is used only for
% traffic and shadowing.
env = build_environment(cfg,seed);
env.T(:) = T;
env.RH(:) = 50;
env.rain(:) = 0;
env.Lrain(:) = 0;
env.Lveg(:) = 0.34*cfg.fc^0.39*cfg.foliage_m^0.25;
env.PL = 32.44 + 20*log10(cfg.dist_km) + 20*log10(cfg.fc) + ...
    env.Lveg + env.Lrain + cfg.Lbody + env.shadow;
arr = build_arrivals(cfg,env,seed);
[m,tr] = simulate_day(cfg,env,arr,pol);
end

function tab = run_openloop_experiment(cfg)
% Fixed 20 dBm for every bandwidth: the narrow receiver keeps its noise
% advantage but cannot convert it into lower transmit power.
pols = make_policies(); nP = 3;          % fixed 5/20/100 only
rows = {};
for p = 1:nP
    es = nan(cfg.tempSeeds,1); ms = nan(cfg.tempSeeds,1);
    for s = 1:cfg.tempSeeds
        env = build_environment(cfg,s);
        arr = build_arrivals(cfg,env,s);
        pol = pols(p); pol.pcontrol = false;
        [m,~] = simulate_day(cfg,env,arr,pol);
        es(s)=m.Eperbit_nJ; ms(s)=m.miss_pct;
    end
    rows(end+1,:) = {pols(p).name,mean(es),mean(ms)}; %#ok<AGROW>
end
tab = cell2table(rows,'VariableNames',{'Policy','Eperbit_nJ','Miss_pct'});
writetable(tab,fullfile(cfg.resdir,'table_openloop.csv'));
end

% =====================================================================
%  SELF-CHECKS  (Section 6)
% =====================================================================
function selfcheck(cfg)
fprintf('\n--- self-checks ---\n');
% 1. 70-day battery anchor at 21.9 mW
[life0,~,~] = battery_life(cfg,21.9e-3*86400,25);
fprintf('1) 37 Wh at 21.9 mW: %.1f days nominal, %.1f days with self-discharge (target 70.4)\n', ...
    cfg.C_nom/(21.9e-3*86400), life0);

% 2. zero-traffic slot
[~,Pidle] = device_power(cfg,20,25,50,-10);
fprintf('2) empty 20 MHz slot: %.4f J (target %.4f J)\n', ...
    Pidle*cfg.dt/1000, 21.9e-3*cfg.dt);

% 3. bit conservation in one FIFO slot
rng(1); a=(0:0.05:1.95)'; L=repmat(cfg.L_tel,40,1);
rate=1e6; dt=10; s=L/rate; C=cumsum(s); off=[0;C(1:end-1)];
D=C+cummax(a-off); served=sum(D<=dt);
fprintf('3) 40 packets, 1 Mbit/s: %d served, bit residual %.2e\n', ...
    served, abs(sum(L(1:served))-rate*C(served))/sum(L));

% 4. link-budget sanity at 110 dB, 20 MHz
N=-174+10*log10(20e6)+cfg.NF;
ptx=cfg.sinr_target+N+110-cfg.Gb; sinr=ptx-110+cfg.Gb-N;
se=min(cfg.se_max,cfg.gap*log2(1+10^(sinr/10)/cfg.snr_gap));
fprintf('4) PL=110 dB, 20 MHz: Ptx=%.1f dBm, SE=%.2f bit/s/Hz\n',ptx,se);
end

% =====================================================================
%  FIGURES
% =====================================================================
function draw_environment(cfg)
env = build_environment(cfg,1);
h = env.h;
f = figure('Color','w','Position',[80 80 1100 780]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

nexttile;
yyaxis left; plot(h,env.T,'LineWidth',1.6); ylabel('T_{amb} [degC]');
yyaxis right; plot(h,env.RH,'LineWidth',1.6); ylabel('RH [%]');
xlabel('Hour of day'); grid on; title('(a) Air temperature and relative humidity');
xlim([0 24]);

nexttile;
yyaxis left; plot(h,env.rain,'LineWidth',1.6); ylabel('Rain rate [mm/h]');
yyaxis right; plot(h,env.Lrain,'--','LineWidth',1.5); hold on;
plot(h,env.Lveg,':','LineWidth',1.5); ylabel('Excess loss [dB]');
legend({'Rain rate','Rain loss, 3.5 GHz','Foliage loss, 3.5 GHz'},'Location','northwest');
xlabel('Hour of day'); grid on; title('(b) Weather-driven excess path loss'); xlim([0 24]);

nexttile;
for B = [20 5 100]
    s = zeros(cfg.K,1);
    for k=1:cfg.K
        [s(k),~,~,~] = link_eval(cfg,B,env,k,true);
    end
    plot(h,s,'LineWidth',1.1); hold on;
end
yline(cfg.sinr_target,'k--'); ylabel('Received SINR [dB]');
xlabel('Hour of day'); grid on; title('(c) SINR at the terminal');
legend({'20 MHz','5 MHz','100 MHz','Target'},'Location','southwest'); xlim([0 24]);

nexttile;
yyaxis left; plot(h,env.users,'LineWidth',1.6); ylabel('Active users on the BWP');
yyaxis right; plot(h,env.load_kbps,'LineWidth',1.6); ylabel('Offered load [kbit/s]');
xlabel('Hour of day'); grid on; title('(d) Spectrum sharing and traffic profile'); xlim([0 24]);

print(f,fullfile(cfg.figdir,'fig2_environment.png'),'-dpng','-r180');
close(f);
end

function draw_rain(cfg)
R = logspace(-1,2.1,60);
k35 = 0.0009; k28 = 0.22;
f = figure('Color','w','Position',[100 100 720 480]);
loglog(R,k35*R,'-o','LineWidth',1.5,'MarkerSize',4); hold on;
loglog(R,k28*R,'-s','LineWidth',1.5,'MarkerSize',4);
grid on; grid minor; xlabel('Rain rate [mm/h]'); ylabel('Specific attenuation [dB/km]');
legend({'3.5 GHz (FR1)','28 GHz (FR2)'},'Location','northwest');
title('ITU-R P.838 specific rain attenuation (alpha = 1 approximation)');
print(f,fullfile(cfg.figdir,'fig6_rain.png'),'-dpng','-r180'); close(f);
end

function draw_day(cfg)
S = load(fullfile(cfg.resdir,'day_traces.mat'));
tr = S.traces;
h = (0:cfg.K-1)*cfg.dt/3600;
mov = @(x) movmean(x,15);
f = figure('Color','w','Position',[80 60 1050 760]);
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');
nexttile;
lab = {'Fixed 100 MHz','Fixed 20 MHz','Fixed 5 MHz','Adaptive'};
ord = [3 2 1 4];
for j = 1:4
    plot(h,mov(tr(ord(j)).Pavg),'LineWidth',1.2); hold on;
end
set(gca,'YScale','log'); ylabel('Average power [mW]'); grid on;
legend(lab,'Location','northwest');
title('(a) Battery load, 2.5-min moving average of E_{slot}/dt');
xlim([0 24]);
nexttile;
stairs(h,tr(4).B,'LineWidth',1.4); ylim([0 110]); yticks([5 20 100]);
xlabel('Hour of day'); ylabel('Selected B [MHz]'); grid on;
title('(b) Bandwidth chosen by the adaptive policy'); xlim([0 24]);
print(f,fullfile(cfg.figdir,'fig3_day.png'),'-dpng','-r180'); close(f);
end

function draw_sweeps(cfg,loadtab,sinrtab)
f = figure('Color','w','Position',[80 60 1120 820]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

nexttile;
for B = cfg.Bset
    r = loadtab(loadtab.SINR20_dB==15 & loadtab.B_MHz==B,:);
    semilogx(r.Load_kbps,r.Eperbit_nJ,'-o','LineWidth',1.4); hold on;
end
xlabel('Offered load [kbit/s]'); ylabel('Energy per delivered bit [nJ]');
grid on; title('(a) Good link, SINR_{20} = 15 dB');
legend({'5 MHz','20 MHz','100 MHz'},'Location','best');

nexttile;
for B = cfg.Bset
    r = loadtab(loadtab.SINR20_dB==0 & loadtab.B_MHz==B,:);
    semilogx(r.Load_kbps,r.Eperbit_nJ,'-o','LineWidth',1.4); hold on;
end
xlabel('Offered load [kbit/s]'); ylabel('Energy per delivered bit [nJ]');
grid on; title('(b) Cell edge, SINR_{20} = 0 dB');
legend({'5 MHz','20 MHz','100 MHz'},'Location','best');

nexttile;
for B = cfg.Bset
    r = sinrtab(sinrtab.B_MHz==B,:);
    plot(r.SINR20_dB,r.Eperbit_nJ,'-o','LineWidth',1.4); hold on;
end
xlabel('SINR_{20} [dB]'); ylabel('Energy per delivered bit [nJ]');
grid on; title('(c) Energy versus SINR at 100 kbit/s');
legend({'5 MHz','20 MHz','100 MHz'},'Location','best');

nexttile;
for B = cfg.Bset
    r = loadtab(loadtab.SINR20_dB==15 & loadtab.B_MHz==B,:);
    semilogx(r.Load_kbps,r.Miss_pct,'-o','LineWidth',1.4); hold on;
end
xlabel('Offered load [kbit/s]'); ylabel('Deadline miss [%]');
grid on; title('(d) Queueing bottleneck at 15 dB');
legend({'5 MHz','20 MHz','100 MHz'},'Location','northwest');

print(f,fullfile(cfg.figdir,'fig4_sweeps.png'),'-dpng','-r180'); close(f);
end

function draw_temperature(cfg,tab)
f = figure('Color','w','Position',[80 60 1050 430]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
names = unique(tab.Policy,'stable');
for i=1:numel(names)
    r = tab(strcmp(tab.Policy,names{i}),:);
    plot(r.T_C,r.BatteryLife_days,'-o','LineWidth',1.4); hold on;
end
xlabel('Ambient temperature [degC]'); ylabel('Projected battery life [days]');
grid on; title('(a) Battery life versus ambient temperature');
legend(names,'Location','best');
nexttile;
for i=1:numel(names)
    r = tab(strcmp(tab.Policy,names{i}),:);
    plot(r.T_C,r.Eperbit_nJ,'-o','LineWidth',1.4); hold on;
end
xlabel('Ambient temperature [degC]'); ylabel('Energy per delivered bit [nJ]');
grid on; title('(b) PA derating and leakage');
legend(names,'Location','best');
print(f,fullfile(cfg.figdir,'fig5_temperature.png'),'-dpng','-r180'); close(f);
end

function draw_openloop(cfg,tab)
f = figure('Color','w','Position',[100 100 760 470]);
b = bar(tab.Eperbit_nJ, 0.55);
b.FaceColor = [0.30 0.55 0.75];
b.EdgeColor = [0.15 0.30 0.45];
set(gca,'XTick',1:height(tab),'XTickLabel',tab.Policy);
xtickangle(25);
ylabel('Energy per delivered bit [nJ]'); grid on;
title('Open loop, fixed 20 dBm: no power-control compensation');
print(f,fullfile(cfg.figdir,'fig7_openloop.png'),'-dpng','-r180'); close(f);
end
