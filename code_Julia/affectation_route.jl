using Random

# Défintion de nouvelle structure pour résoudre le problème
mutable struct Livraison  
    e::Int
    f::Int
    q::Int

    Livraison(;e,f,q) = new(e, f, q)
end

mutable struct Camion
    u::Int
    j::Int
    longueur::Int
    fournisseurs::Vector{Int}
    livraison::Vector{Livraison}    
    
    Camion(;u,j, longueur, fournisseurs,livraison) = new(u, j, longueur, fournisseurs, livraison)
end
    
# en vue d'utilisation de l'heuritsique first-fit deacreasing
function tri_emballage(emballages)
    emb_tri = Vector{Int}([emballages[1].e])
    for e1 in 2:dims.E
        push!(emb_tri, e1)
        e2 = e1
        while emballages[e2].l > emballages[e2 - 1].l && e2 - 1 >= 1
            emb_tri[e2], emb_tri[e2 - 1] = emb_tri[e2 - 1], emb_tri[e2]
            e2 -= 1
        end
    end
    return emb_tri
end

# Calcul la longueur totale d'emballage du fournisseur f
function l_tot(flux_opt, j, u, f)
    l_tot = 0
    for e in 1:dims.E
        l_tot = l_tot + flux_opt[e,j,u,f] * emballages[e].l
    end
    return l_tot
end

function non_vide(flux_opt, j, u)
    for f in 1:dims.F
        for e in 1:dims.E
            if flux_opt[e,j,u,f] == 0
                return true
            end
        end
    end
    return false
end


# Renvoie la liste des fournisseurs devant être livré par l'usine u en j
function fournisseurs_cibles(flux_opt, j, u)
    fournisseurs_cibles = Vector{Int}()
    for f in 1:dims.F
        for e in 1:dims.E
            if flux_opt[e,j,u,f] > 0 && !(f in fournisseurs_cibles)
                push!(fournisseurs_cibles, f)
            end
        end
    end
    return fournisseurs_cibles
end

# Tri les fournisseurs par taille de livraison
function tri_fournisseur(flux_opt, j, u)
    fournisseurs_tries = [fournisseurs[1].f]
    for f1 in 2:dims.F
        push!(fournisseurs_tries, f1)
        f2 = f1 
        while f2 - 1 >= 1 && l_tot(flux_opt, j, u, fournisseurs[f2].f) > l_tot(flux_opt, j, u, fournisseurs[f2 - 1].f)
            fournisseurs_tries[f2 - 1], fournisseurs_tries[f2] = fournisseurs_tries[f2], fournisseurs_tries[f2 - 1]
            f2 -= 1
        end
    end
    return fournisseurs_tries
end

# Remplis un camion pour un fournisseur et un emballage 
function remplis_camion(camion::Camion, flux::Int, e::Int, f::Int)
    push!(camion.livraison, Livraison(e=e, f=f, q=1))
    camion.longueur += emballages[e].l
    flux -= 1 
    while camion.longueur + emballages[e].l <= dims.L && flux > 0
        last(camion.livraison).q += 1
        camion.longueur += emballages[e].l
        flux -= 1 
    end
    return (camion, flux)
end

# Affecte les camions au sein d'un cluster 
function affectation_camions_cluster(saved_flux_opt, cluster, emballages_tries, j, u)
    flux_opt = deepcopy(saved_flux_opt)
    camions_cluster = Vector{Camion}()
    for f in cluster          
        for e in emballages_tries
            if flux_opt[e,j,u,f] > 0
                for camion in camions_cluster
                    if length(camion.fournisseurs) <= 4 &&  flux_opt[e,j,u,f] > 0   # si la route n'est pas pleine et qu'il reste du flux
                        if camion.longueur + emballages[e].l <= dims.L  # si ça rentre 
                            if !(f in camion.fournisseurs) && length(camion.fournisseurs) <= 3  # si le fournisseur n'était pas déjà dans le trajet
                                push!(camion.fournisseurs, f)
                            end
                            if f in camion.fournisseurs      # mtn qu'il appartient à la route 
                                (camion, flux_opt[e,j,u,f]) = remplis_camion(camion, flux_opt[e,j,u,f], e, f)
                            end
                        end
                    end
                end
                while flux_opt[e,j,u,f] > 0
                    push!(camions_cluster, Camion(u=u, j=j, longueur=0, fournisseurs=Vector{Int}(), livraison=Vector{Livraison}()))
                    push!(last(camions_cluster).fournisseurs, f)
                    (camions_cluster[length(camions_cluster)], flux_opt[e,j,u,f]) = remplis_camion(last(camions_cluster), flux_opt[e,j,u,f], e, f)
                end
            end
        end
    end
    return camions_cluster
end

# Crée Les clusters
function clustering(flux, j, u, cluster_size)
    ensemble_cluster = Vector{Vector{Int}}()
    liste_fournisseurs = fournisseurs_cibles(flux, j, u)
    n = length(liste_fournisseurs)
    sort!(liste_fournisseurs, by=f -> -graphe.d[u,f + dims.U])
    while length(liste_fournisseurs) != 0
        cluster = Vector{Int}()
        origine = popfirst!(liste_fournisseurs)
        push!(cluster, origine)
        liste_cluster = copy(liste_fournisseurs)
        sort!(liste_cluster, by=f -> graphe.d[origine + dims.U,f + dims.U])
        for i in 1:(cluster_size - 1)
            if length(liste_cluster) == 0
                break
            end
            # origine=popfirst!(liste_cluster)
            nouveau = popfirst!(liste_cluster)
            push!(cluster, nouveau)
            # println("distance nouveau-origine : ", graphe.d[origine + dims.U,nouveau + dims.U])
            deleteat!(liste_fournisseurs, liste_fournisseurs .== nouveau)
            # sort!(liste_cluster, by=f -> -graphe.d[origine + dims.U,f + dims.U])
        end
        push!(ensemble_cluster, cluster)
    end
    # for i in 1:length(ensemble_cluster)
    #     println("longueur du cluster ", i, " : ", length(ensemble_cluster[i]))
    # end
    return ensemble_cluster
end

# Affecte tous les camions 
function affectation_camions_globale(saved_flux_opt, emballages_tries, cluster_size=4)::Vector{Camion}
    println("taille cluster : ", cluster_size)
    emballages_tries = tri_emballage(emballages)
    camions = Vector{Camion}()
    for j in 1:dims.J
        println("j : ", j)
        for u in 1:dims.U
            flux_opt = deepcopy(saved_flux_opt)
            fournisseurs_ju = fournisseurs_cibles(flux_opt, j, u)
            # println("nb de fournisseurs cibles ", length(fournisseurs_ju))
            clusters = clustering(flux_opt, j, u, cluster_size)
            for cluster in clusters
                camions = vcat(camions, affectation_camions_cluster(flux_opt, cluster, emballages_tries, j, u))
            end
        end
    end
    return camions
end


# recherche locale sur la liste de priorité de fournisseurs
function recherche_bourrin(N, saved_flux_opt, emballages_tries, fournisseurs_ju, j, u)::Vector{Camion}
    println("ju", j, u)
    flux_opt = copy(saved_flux_opt)
    camions = affectation_camions(flux_opt, emballages_tries, fournisseurs_ju, j, u)
    routes = construit_routes(camions)
    cost = cost_routes(routes, instance)
    for i in 1:N * length(fournisseurs_ju)
        flux_opt = copy(saved_flux_opt)
        fournisseurs_ju = shuffle(fournisseurs_ju)
        new_camions = affectation_camions(flux_opt, emballages_tries, fournisseurs_ju, j, u)
        new_routes = construit_routes(new_camions)
        new_cost = cost_routes(new_routes, instance)
        if new_cost < cost
            camions = new_camions
            cost = new_cost
        end
    end
    return camions
end

function longueur_moyenne_camion(affectation::Vector{Camion})
    moyenne = 0
    for camion in affectation
        moyenne += camion.longueur
    end
    return moyenne / length(affectation)
end

function route_stop_non_vide(route_stop)
    for e in 1:dims.E
        if route_stop.Q[e] > 0
            return true
        end
    end
    return false
end

# Construit les routes à partir des camions
function construit_routes(affectation)
    R = 0
    Routes = Vector{Route}()
    for camion in affectation
        stops = Vector{RouteStop}()
        for f in camion.fournisseurs
            Q = zeros(dims.E)
            route_stop = RouteStop(f=f, Q=Q)
            for livraison in camion.livraison
                if f == livraison.f
                    route_stop.Q[livraison.e] += livraison.q
                end
            end
            if route_stop_non_vide(route_stop)
                push!(stops, route_stop)
            end
        end
        if length(stops) > 0
            R += 1
            push!(Routes, Route(r=R, j=camion.j, x=1, u=camion.u, F=length(camion.fournisseurs), stops=stops))
        end
    end
    return Routes
end

permutations12 = [[1,2],[2,1]]
permutations123 = [[1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1]]
permutations1234 = [[1,2,3,4],[1,2,4,3],[1,3,2,4],[1,3,4,2],[1,4,2,3],[1,4,3,2],
                [2,1,3,4],[2,1,4,3],[2,3,1,4],[2,3,4,1],[2,4,1,3],[2,4,3,1],
                [3,1,2,4],[3,1,4,2],[3,2,1,4],[3,2,4,1],[3,4,1,2],[3,4,2,1],
                [4,1,2,3],[4,1,3,2],[4,2,1,3],[4,2,3,1],[4,3,1,2],[4,3,2,1]]
  
# Teste toutes les possibilités dans l'ordre de livraions de chaque camion
function optim_tournee_chaque_camion(Routes)
    Routes_opti_loc = Vector{Route}()
    for route in Routes
        meilleure_route = route
        meilleur_cout = cost(meilleure_route, instance)
        # route_possible = Vector{Route}()
        # push!(route_possible, route)
        if length(route.stops) == 4
            for (i, j, k, l) in permutations1234
                new_route = Route(r=route.r, j=route.j, u=route.u, x=route.x, F=route.F, stops=[route.stops[i],route.stops[j],route.stops[k],route.stops[l]])
                new_cost = cost(new_route, instance)
                if new_cost < meilleur_cout
                    meilleure_route = new_route
                    meilleur_cout = new_cost
                end
            end
        elseif length(route.stops) == 3
            for (i, j, k) in permutations123
                new_route = Route(r=route.r, j=route.j, u=route.u, x=route.x, F=route.F, stops=[route.stops[i],route.stops[j],route.stops[k]])
                new_cost = cost(new_route, instance)
                if new_cost < meilleur_cout
                    meilleure_route = new_route
                    meilleur_cout = new_cost
                end
            end
        elseif length(route.stops) == 2
            for (i, j) in permutations12
                new_route = Route(r=route.r, j=route.j, u=route.u, x=route.x, F=route.F, stops=[route.stops[i],route.stops[j]])
                new_cost = cost(new_route, instance)
                if new_cost < meilleur_cout
                    meilleure_route = new_route
                    meilleur_cout = new_cost
                end
            end
        end
        push!(Routes_opti_loc, meilleure_route)
    end
    return Routes_opti_loc
end
   



                            
                                    



