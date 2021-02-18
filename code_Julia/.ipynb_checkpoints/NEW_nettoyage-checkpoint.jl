using SparseArrays
using LightGraphs
using ProgressMeter
using LinearAlgebra

##Reduction du graphe par selection des Nprofondeur voisins

const Nprofondeur = 1

function a_portee(v1::Int,v2::Int,Iterees::Vector{Matrix{Int}})::Bool
    #v2 est il à portée de v1
    flag = true
    for i in 1:Nprofondeur
            flag = flag && (Iterees[i][v1,v2] != 0)
    end
    return flag
end
    
#La fonction agit par effet de bord
function nettoie_graphe(Chemins::Graphe)::Nothing
    Iterees = Vector{Matrix{Int}}(undef,Nprofondeur)
    Iterees[1] = Chemins.d
    
    #Iterees[i] = d^i normalement, donne les chemins de longueur k
    for i in 2:Nprofondeur
        Iterees[i] = Iterees[i-1]*Chemins.d
    end

    for edge in edges(Chemins.G)
        if (!a_portee(edge.src,edge.dst,Iterees))
            rem_edge!(Chemins.G, edge)
        end
    end
end
