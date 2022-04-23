using TSPDrone 
using TSPLIB
using Concorde
using Statistics

function read_data(subfolder, instance)
    file = open(joinpath(@__DIR__, "..", subfolder, instance), "r")

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

    return x, y, truck_cost_factor, drone_cost_factor
end

function test_TSPLIB100()
    instances = [:kroA100, :kroC100, :kroD100, :kroE100, :rd100]
    for inst in instances
        tsp = readTSPLIB(inst)
        x = tsp.nodes[:, 1]
        y = tsp.nodes[:, 2]
        truck_cost_factor = 1.0
        drone_cost_factor = 0.5

        manhattan_dist_mtx = [abs(x[i]-x[j]) + abs(y[i]-y[j]) for i in 1:tsp.dimension, j in 1:tsp.dimension]
        dist_mtx = round.(Int, manhattan_dist_mtx ./ 40 .* 100)
        tsp_tour, tsp_len = solve_tsp(dist_mtx)

        drone_dist_mtx = tsp.weights ./40 .* 100
        truck_dist_mtx = manhattan_dist_mtx ./ 40 .* 100

        flying_range = 40 * 40/60 * 100

        objective_value, truck_route, drone_route = solve_tspd(truck_dist_mtx, drone_dist_mtx, flying_range=flying_range, n_groups=10, method="TSP-ep-all")

        println("$(inst), tsp=$(tsp_len), tspd=$(objective_value)")

    end
end

function test_agatz(dist, n_nodes; n_samples=0, device="cpu")
    filenames = Dict()
    filenames[10] = ["$(dist)-$(50 + i)-n10.txt" for i in 1:10]
    filenames[20] = ["$(dist)-$(60 + i)-n20.txt" for i in 1:10]
    filenames[50] = ["$(dist)-$(70 + i)-n50.txt" for i in 1:10]
    filenames[75] = ["$(dist)-$(80 + i)-n75.txt" for i in 1:10]
    filenames[100] = ["$(dist)-$(90 + i)-n100.txt" for i in 1:10]
    filenames[175] = ["$(dist)-$(100 + i)-n175.txt" for i in 1:10]
    filenames[250] = ["$(dist)-$(110 + i)-n250.txt" for i in 1:10]

    for n in n_nodes
        n_grp = n < 25 ? 1 : Int(n / 25)
        # n_grp = 1
        
        objs = Float64[]
        objs_RL = Float64[]

        if n_samples == 0
            t = time()
            for filename in filenames[n]
                x, y, truck_cost_factor, drone_cost_factor = read_data(dist, filename)
                
                # manhattan_dist_mtx = [abs(x[i]-x[j]) + abs(y[i]-y[j]) for i in 1:n, j in 1:n]
                # euclidean_dist_mtx = [sqrt((x[i]-x[j])^2 + (y[i]-y[j])^2) for i in 1:n, j in 1:n]
                
                # truck_dist_mtx = euclidean_dist_mtx ./ 40 .* 100
                # drone_dist_mtx = manhattan_dist_mtx ./ 40 ./ 2 .* 100

                # objective_value, truck_route, drone_route = solve_tspd(truck_dist_mtx, drone_dist_mtx; n_groups=n_grp, method="TSP-ep-all")

                obj, _, _ = solve_tspd(x, y, truck_cost_factor, drone_cost_factor; n_groups=n_grp, method="TSP-ep-all")
                @show filename, obj, n_grp
                push!(objs, obj)
            end
            t_dps = time() - t

            open("$(dist)-n$n-DPS-n_groups_$(n_grp).txt", "w") do io 
                println(io, objs)
                println(io, mean(objs))
                println(io, t_dps / 10)
            end
        end

        if n_samples > 0

            t = time()
            for filename in filenames[n]
                x, y, truck_cost_factor, drone_cost_factor = read_data(dist, filename)

                @assert truck_cost_factor / drone_cost_factor == 2.0
                obj_value, _, _ = solve_tspd_RL(x, y, n_samples=n_samples, device=device)
                @show filename, obj_value, n_grp
                push!(objs_RL, obj_value[1])
            end
            t_rl = time() - t

            open("$(dist)-n$n-RL-n_samples_$(n_samples).txt", "w") do io
                println(io, objs_RL)
                println(io, mean(objs_RL))
                println(io, t_rl / 10)
            end

        end

        println("n = $(n), mean(DPS25)= $(mean(objs)), mean(RL) = $(mean(objs_RL))")

    end

end

#test_agatz(n_samples=1, device="cpu")

# test_agatz("uniform", [10, 20, 50, 75, 100, 175, 250]; n_samples=0, device="cuda")
# test_agatz("singlecenter", [10, 20, 50, 75, 100, 175, 250]; n_samples=0, device="cuda")
# test_agatz("doublecenter", [10, 20, 50, 75, 100, 175, 250]; n_samples=0, device="cuda")

# test_agatz("uniform", [20, 50, 100]; n_samples=1, device="cuda")
# test_agatz("singlecenter", [20, 50, 100]; n_samples=1, device="cuda")
# test_agatz("doublecenter", [20, 50, 100]; n_samples=1, device="cuda")


# Please run these:
test_agatz("uniform", [20, 50, 100]; n_samples=1, device="cuda")
test_agatz("uniform", [20, 50, 100]; n_samples=4800, device="cuda")