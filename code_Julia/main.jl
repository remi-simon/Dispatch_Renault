# charge les fonctions
include("import_all.jl")

# lit les instances 
data = open(joinpath(@__DIR__, "..", "instance", "europe.csv"), "r+") do file
    readlines(file)
end
dims = lire_dimensions(data[1])
emballages = [lire_emballage(data[1 + e], dims) for e = 1:dims.E]

fournisseurs = [lire_fournisseur(data[1 + dims.E + dims.U + f], dims) for f = 1:dims.F]
usines = [lire_usine(data[1 + dims.E + u], dims) for u = 1:dims.U]
instance = lire_instance(joinpath(@__DIR__, "..", "instance", "europe.csv"))
graphe = lire_graphe(data[1 + dims.E + dims.U + dims.F + 1:end], dims)

# Détermine les flux d'emballage
saved_flux_opt, objectif = calcul_flux_opt_horizon()
flux_opt = copy(saved_flux_opt)
cluster_size = 4

# Construit les camions par clusters
camions = affectation_camions_globale(flux_opt, tri_emballage(emballages), cluster_size)

# construit et optimise les routes
instance.routes = construit_routes(camions)
instance.R = length(instance.routes)
instance.routes = optim_tournee_chaque_camion(instance.routes)
update_stocks!(instance, instance.routes)

# Obtient le résultat
cost_inst = cost_verbose(instance)
println(feasibility(instance))


