"Check whether formulas can be satisfied in a given state."
function satisfy(formulas::Vector{<:Term}, state::State,
                 domain::Union{Domain,Nothing}=nothing; mode::Symbol=:any)
    # Initialize FOL knowledge base to the set of facts
    clauses = state.facts
    # If domain is provided, add domain axioms and type clauses
    if domain != nothing
        clauses = Clause[clauses; domain.axioms; type_clauses(domain.types)]
    end
    # Pass in fluents as a dictionary of functions
    funcs = state.fluents
    return resolve(formulas, clauses; funcs=funcs, mode=mode)
end

satisfy(formula::Term, state::State, domain::Union{Domain,Nothing}=nothing;
        options...) = satisfy(Term[formula], state, domain; options...)

"Create initial state from problem definition."
function initialize(problem::Problem)
    types = [@fol($ty(:o) <<= true) for (o, ty) in problem.objtypes]
    facts = Clause[]
    fluents = Dict{Symbol,Any}()
    for clause in problem.init
        if clause.head.name == :(==)
            # Initialize fluents
            term, val = clause.head.args[1], clause.head.args[2]
            @assert !isa(term, Var) "Initial terms cannot be unbound variables."
            @assert isa(val, Const) "Terms must be initialized to constants."
            if isa(term, Const)
                # Assign term to constant value
                fluents[term.name] = val.name
            else
                # Assign entry in look-up table
                lookup = get!(fluents, term.name, Dict())
                lookup[Tuple(a.name for a in term.args)] = val.name
            end
        else
            push!(facts, clause)
        end
    end
    return State([facts; types], fluents)
end

"Convert type hierarchy to list of FOL clauses."
function type_clauses(typetree::Dict{Symbol,Vector{Symbol}})
    clauses = [[Clause(@fol($ty(X)), Term[@fol($s(X))]) for s in subtys]
               for (ty, subtys) in typetree if length(subtys) > 0]
    return length(clauses) > 0 ? reduce(vcat, clauses) : Clause[]
end
