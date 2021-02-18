using JuMP, Gurobi


# Programme linéaire pour fixer les flux entiers d'emballages,
# la formulation est parfaite donc nous avons pu relâcher les contraintes
function calcul_flux_horizon(e::Int)
    model = Model(Gurobi.Optimizer)
    set_optimizer(model, Gurobi.Optimizer)
    set_optimizer_attribute(model, "OutputFlag", 0)
    

    @variable(model, 0 <= y[1:dims.U, 1:dims.F, 1:dims.J]) # y[u,f,j] correspond à la quantité d'emballage e qui part de l'usine k vers le fournisseur i le jour j
    @variable(model, 0 <= s_u[1:dims.U,1:dims.J])  # s[e,u,j]  stock de e en u à j
    @variable(model, 0 <= s_f[1:dims.F,1:dims.J])  # s[e,f,j]  stock de e en f à j
    @variable(model, 0 <=  z⁺[1:dims.F,1:dims.J])  # z⁺[e,f,j] flux de e qui arrive en f à j
    @variable(model, 0 <=  z⁻[1:dims.U,1:dims.J])  # z⁻[e,u,j] flux de e qui part de u à j

    @variable(model, 0 <= a[1:dims.U, 1:dims.J]) # a,b,c,l nous servent à linéariser les expressions
    @variable(model, 0 <= b[1:dims.F, 1:dims.J])
    @variable(model, 0 <= c[1:dims.F, 1:dims.J])
    @variable(model, 0 <= l[1:dims.F, 1:dims.J])

# y[u,f]*emballages[e].l/dims.L est une approximation du nombre de camions nécessaires pour transférer la quantité y[u,f] de u à f
    @objective(model, Min, 
    sum(( dims.ccam + dims.cstop +  dims.γ * graphe.d[u,dims.U + f] ) * y[u,f,j] * emballages[e].l / dims.L for u in 1:dims.U for f in 1:dims.F for j in 1:dims.J) +
    sum(usines[u].cs[e] * a[u,j] for u in 1:dims.U for j in 1:dims.J) +
    sum(fournisseurs[f].cs[e] * b[f,j] + fournisseurs[f].cexc[e] * c[f,j]  for f in 1:dims.F for j in 1:dims.J))

    # @constraint(model,cgraphe[u in 1:dims.U,f in 1:dims.F,j in 1:dims.J], y[u,f,j] <= 1000 * has_edge(graphe.G, u, dims.U + f))

    @constraint(model, c11[u in 1:dims.U], (s_u[u,1] == usines[u].s0[e] + usines[u].b⁺[e, 1] - z⁻[u,1])) # contrainte 1 pour j=1
    @constraint(model, c12[u in 1:dims.U,j in 2:dims.J], (s_u[u,j] == s_u[u,j - 1] + usines[u].b⁺[e, j] - z⁻[u,j])) # contrainte 1 pourj>1
    
    @constraint(model, c6[f in 1:dims.F,j in 1:dims.J], (s_f[f,j] == l[f,j] + z⁺[f,j])) # contrainte 6

    @constraint(model,c10a[u in 1:dims.U, j in 1:dims.J], (z⁻[u,j] == sum(y[u,f,j] for f in 1:dims.F))) # contrainte 10a
    @constraint(model,c10b[f in 1:dims.F, j in 1:dims.J], (z⁺[f,j] == sum(y[u,f,j] for u in 1:dims.U))) # contrainte 10b

    # contraintes de linéarisation
    @constraint(model, s_f_carton1[f in 1:dims.F], l[f,1] ==  c[f,1] + fournisseurs[f].s0[e] - fournisseurs[f].b⁻[e, 1])

    @constraint(model, s_f_carton2[f in 1:dims.F, j in 2:dims.J], l[f,j] ==  c[f,j] + s_f[f, j - 1] - fournisseurs[f].b⁻[e,j] )

    
    @constraint(model, s_u_ss[u in 1:dims.U, j in 1:dims.J], a[u,j] >= s_u[u,j] - usines[u].r[e,j] ) 
    @constraint(model, s_f_ss[f in 1:dims.F,j in 1:dims.J], b[f,j] >= s_f[f,j] - fournisseurs[f].r[e, j] )

    
    @constraint(model, c_carton1[f in 1:dims.F], c[f,1] >= fournisseurs[f].b⁻[e,1] - fournisseurs[f].s0[e])
    @constraint(model, c_carton2[f in 1:dims.F,j in 2:dims.J], c[f,j] >= fournisseurs[f].b⁻[e,j] - s_f[f, j - 1])
    
    optimize!(model)

    # println(termination_status(model))
    objectif = objective_value(model)
    println("objectif: ", objectif)
    flux = value.(y)
    usine_stock = value.(s_u)
    fournisseur_stock = value.(s_f)
    flux_entrant = value.(z⁺)
    flux_sortant = value.(z⁻)
    
    return (flux, usine_stock, fournisseur_stock, flux_entrant, flux_sortant, objectif)
end


function vide_stock()
    for u in 1:dims.U
        for e in 1:dims.E
            for j in 1:dims.J
                usines[u].s[e,j] = 0
            end
        end
    end
    for f in 1:dims.F
        for e in 1:dims.E
            for j in 1:dims.J
                fournisseurs[f].s[e,j] = 0
            end
        end
    end
end
# vide_stock()


# Effetctue la PL sur le problème entier
function calcul_flux_opt_horizon()
    vide_stock()
    objectif_tot = 0
    flux_opt = zeros(Int, dims.E, dims.J, dims.U, dims.F)
    for e in 1:dims.E    
        println("emballage ", e)
        flux, usine_stock, fournisseur_stock, flux_entrant, flux_sortant, objectif = calcul_flux_horizon(e)
        objectif_tot += objectif
        for j in 1:dims.J
            for u in 1:dims.U
                usines[u].s[e,j ] = usine_stock[u,j]
                usines[u].z⁻[e,j ] = flux_sortant[u,j]
            end
            for f in 1:dims.F
                fournisseurs[f].s[e,j ] = fournisseur_stock[f,j]
                fournisseurs[f].z⁺[e,j ] = flux_entrant[f,j]
            end
            for u in 1:dims.U
                for f in 1:dims.F 
                    flux_opt[e,j,u,f] = flux[u,f,j]
                end
            end
        end
    end
    return flux_opt, objectif_tot
end

function affiche_flux(flux)
    for j in 1:dims.J
        for u in 1:dims.U
            println("Flux sortant de l'usine ", u, " le jour ", j, " : ", flux[:,j,u,:])
        end
    end
end
