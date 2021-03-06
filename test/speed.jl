#############################################################################
# JuMP
# An algebraic modelling langauge for Julia
# See http://github.com/IainNZ/JuMP.jl
#############################################################################
# speed.jl
#
# Runs some JuMP benchmarks to test for speed-related regressions.
# Examples taken from the Lubin, Dunning paper.
# 
# Post past results here
# -------------------------
# 2013/10/05  Iain's Dell Laptop
# Run 1
# PMEDIAN BUILD MIN=0.37519394   MED=0.72586158
# PMEDIAN WRITE MIN=1.551488986  MED=1.62851847
# CONT5 BUILD   MIN=0.254537676  MED=0.454625898
# CONT5 WRITE   MIN=1.581302132  MED=1.639451427
# Run 2
# PMEDIAN BUILD MIN=0.381689249  MED=0.745308535
# PMEDIAN WRITE MIN=1.55169788   MED=1.580791808
# CONT5 BUILD   MIN=0.248255523  MED=0.454527841
# CONT5 WRITE   MIN=1.60369395   MED=1.638122135
#############################################################################

using JuMP

function pMedian(numFacility::Int,numCustomer::Int,numLocation::Int,useMPS)
  srand(10)	
  customerLocations = [rand(1:numLocation) for a = 1:numCustomer ]

  tic()
  m = Model(:Max)

  # Facility locations
  @defVar(m, 0 <= s[1:numLocation] <= 1)

  # Aux. variable: x_a,i = 1 iff the closest facility to a is at i
  @defVar(m, 0 <= x[1:numLocation,1:numCustomer] <= 1)

  # Objective: min distance
  @setObjective(m, sum{abs(customerLocations[a]-i)*x[i,a], a = 1:numCustomer, i = 1:numLocation} )

  # Constraints
  for a in 1:numCustomer
    # Subject to linking x with s
    for i in 1:numLocation
      @addConstraint(m, x[i,a] - s[i] <= 0)
    end
    # Subject to one of x must be 1
    @addConstraint(m, sum{x[i,a],i=1:numLocation} == 1 )
  end

  # Subject to must allocate all facilities
  @addConstraint(m, sum{s[i],i=1:numLocation} == numFacility )	
  buildTime = toq()

  tic()
  if useMPS
    writeMPS(m,"/dev/null")
  else
    writeLP(m,"/dev/null")
  end
  writeTime = toq()

  return buildTime, writeTime
end

function cont5(n,useMPS)
  m = n
  n1 = n-1
  m1 = m-1
  dx = 1/n
  T = 1.58
  dt = T/m
  h2 = dx^2
  a = 0.001
  yt = [0.5*(1 - (j*dx)^2) for j=0:n]
	
  tic()
  mod = Model(:Min)
  @defVar(mod,  0 <= y[0:m,0:n] <= 1)
  @defVar(mod, -1 <= u[1:m] <= 1)
  @setObjective(mod, y[0,0])

  # PDE
  for i = 0:m1
    for j = 1:n1
      @addConstraint(mod, h2*(y[i+1,j] - y[i,j]) == 0.5*dt*(y[i,j-1] - 2*y[i,j] + y[i,j+1] + y[i+1,j-1] - 2*y[i+1,j] + y[i+1,j+1]) )
    end
  end

  # IC
  for j = 0:n
    @addConstraint(mod, y[0,j] == 0)
  end

  # BC
  for i = 1:m
    @addConstraint(mod, y[i,2]   - 4*y[i,1]  + 3*y[i,0] == 0)
    @addConstraint(mod, y[i,n-2] - 4*y[i,n1] + 3*y[i,n] == (2*dx)*(u[i] - y[i,n]))
  end
  buildTime = toq()

  tic()
  if !useMPS
    writeLP(mod, "/dev/null")
  else
    writeMPS(mod, "/dev/null")
  end
  writeTime = toq()

  return buildTime, writeTime
end


function RunTests()
  # Pmedian
  pmedian_build = Float64[]
  pmedian_write = Float64[]
  for runs = 1:9
    bt, wt = pMedian(100,100,5000,false)
    push!(pmedian_build, bt)
    push!(pmedian_write, wt)
  end
  sort!(pmedian_build)
  sort!(pmedian_write)
  print("PMEDIAN BUILD MIN=",min(pmedian_build),"  MED=",pmedian_build[5],"\n")
  print("PMEDIAN WRITE MIN=",min(pmedian_write),"  MED=",pmedian_write[5],"\n")

  # Cont5
  cont5_build = Float64[]
  cont5_write = Float64[]
  for runs = 1:9
    bt, wt = cont5(500,false)
    push!(cont5_build, bt)
    push!(cont5_write, wt)
  end
  sort!(cont5_build)
  sort!(cont5_write)
  print("CONT5 BUILD   MIN=",min(cont5_build),"  MED=",cont5_build[5],"\n")
  print("CONT5 WRITE   MIN=",min(cont5_write),"  MED=",cont5_write[5],"\n")

end

RunTests()

