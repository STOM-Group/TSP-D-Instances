using TSPDrone 
using TSPLIB
using Concorde
using Statistics

include("sasan.jl")
include("xufei.jl")

function read_data_range(subfolder, instance)
    file = open(joinpath(@__DIR__, "..", subfolder, instance), "r")

    #MAXFLY 10.31746092796091
    maxfly = split(readline(file), " ")[2]
    if maxfly == "Infinity"
        flying_range = 1e6
    else
        flying_range = parse(Float64, maxfly) 
    end

    readline(file) # an empty line 

    readline(file) # /*The speed of the Truck*/
    truck_cost_factor = parse(Float64, readline(file))
    
    readline(file) # /*The speed of the Drone*/
    drone_cost_factor = parse(Float64, readline(file))
    
    readline(file) # /*Number of Nodes*/
    n_nodes = parse(Int, readline(file))
    
    readline(file) # /*The Depot*/
    depot = split(readline(file), " ")
    depot_coordinates = parse.(Float64, depot[1:2])
    
    readline(file) # /*The Locations (x_coor y_coor name)*/
    customer_coordinates = Matrix{Float64}(undef, n_nodes-1, 2)
    for i in 1:n_nodes-1
        customer = split(readline(file), " ")
        customer_coordinates[i, :] = parse.(Float64, customer[1:2])   
    end
    
    x = vcat(depot_coordinates[1], customer_coordinates[:, 1])
    y = vcat(depot_coordinates[2], customer_coordinates[:, 2])

    close(file)

    return x, y, truck_cost_factor, drone_cost_factor, flying_range
end

function test_agatz_range(n_nodes; n_samples=0, device="cpu")
    filenames = Dict()
    radii = [20, 40, 60, 100, 150, 200]
    filenames[10] = ["uniform-$(50+i)-n10-maxradius-$r.txt" for i in 1:10 for r in radii]

    for n in n_nodes
        # n_grp = n < 25 ? 1 : Int(n / 25)
        n_grp = 1
        
        objs = Float64[]
        objs_RL = Float64[]

        if n_samples == 0
            t = time()
            for filename in filenames[n]
                x, y, truck_cost_factor, drone_cost_factor, flying_range = read_data_range("restricted/maxradius", filename)
                
                # manhattan_dist_mtx = [abs(x[i]-x[j]) + abs(y[i]-y[j]) for i in 1:n, j in 1:n]
                # euclidean_dist_mtx = [sqrt((x[i]-x[j])^2 + (y[i]-y[j])^2) for i in 1:n, j in 1:n]
                
                # truck_dist_mtx = euclidean_dist_mtx ./ 40 .* 100
                # drone_dist_mtx = manhattan_dist_mtx ./ 40 ./ 2 .* 100

                # objective_value, truck_route, drone_route = solve_tspd(truck_dist_mtx, drone_dist_mtx; n_groups=n_grp, method="TSP-ep-all")

                result = solve_tspd(x, y, truck_cost_factor, drone_cost_factor; n_groups=n_grp, method="TSP-ep-all", flying_range=flying_range)
                push!(objs, result.total_cost)

                bigM = 1e4

                Ct, Cd = TSPDrone.cost_matrices_with_dummy(x, y, truck_cost_factor, drone_cost_factor)
                xT_out, xD_out, yT_out, yD_out, yC_out, a_out, obj_val = solve_Optimal_TSPd(Ct, Cd, flying_range, bigM)

                Gurobi_time, Gurobi_sol, Gurobi_tr, Gurobi_dr = formulation(Ct[1:end-1,1:end-1], Ct[1:end-1, 1:end-1], length(x), flying_range, bigM)

                @info filename
                @show flying_range
                println("TSP-ep-all = ", result.total_cost)
                println("sasan      = ", obj_val)
                println("xufei      = ", Gurobi_sol)
                if result.total_cost < obj_val
                    

            end
            t_dps = time() - t

            # open("range-n$n-DPS-n_groups_$(n_grp).txt", "w") do io 
            #     println(io, objs)
            #     println(io, mean(objs))
            #     println(io, t_dps / 10)
            # end
        end

    end

end

# Please run these:
# test_agatz("uniform", [20, 50, 100]; n_samples=1, device="cuda")
# test_agatz("uniform", [20, 50, 100]; n_samples=4800, device="cuda")

gurobi_env = Gurobi.Env()

test_agatz_range(10)