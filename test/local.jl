using DiffEqSensitivity,OrdinaryDiffEq, ModelingToolkit,
      RecursiveArrayTools, DiffEqBase, ForwardDiff, Calculus
using Test
using DiffEqSensitivity: SensitivityAlg

function fb(du,u,p,t)
  du[1] = dx = p[1]*u[1] - p[2]*u[1]*u[2]
  du[2] = dy = -p[3]*u[2] + u[1]*u[2]
end
function jac(J,u,p,t)
  (x, y, a, b, c) = (u[1], u[2], p[1], p[2], p[3])
  J[1,1] = a + y * b * -1
  J[2,1] = y
  J[1,2] = b * x * -1
  J[2,2] = c * -1 + x
end

f = ODEFunction(fb,jac=jac)
p = [1.5,1.0,3.0]
prob = ODELocalSensitivityProblem(f,[1.0;1.0],(0.0,10.0),p)
probInpl = ODELocalSensitivityProblem(fb,[1.0;1.0],(0.0,10.0),p)
probnoad = ODELocalSensitivityProblem(fb,[1.0;1.0],(0.0,10.0),p,
                                      SensitivityAlg(autodiff=false))
sol = solve(prob,Tsit5(),abstol=1e-14,reltol=1e-14)
@test_broken solInpl = solve(probInpl,KenCarp4(),abstol=1e-14,reltol=1e-14)
@test_broken solInpl2 = solve(probInpl,Rodas4(autodiff=false),abstol=1e-14,reltol=1e-14)
solInpl = solve(probInpl,KenCarp4(autodiff=false),abstol=1e-14,reltol=1e-14)
solInpl2 = solve(probInpl,Rodas4(autodiff=false),abstol=1e-14,reltol=1e-14)
solnoad = solve(probnoad,KenCarp4(autodiff=false),abstol=1e-14,reltol=1e-14)

x = sol[1:sol.prob.f.numindvar,:]

@test sol(5.0) ≈ solnoad(5.0)
@test sol(5.0) ≈ solInpl(5.0)
@test solInpl(5.0) ≈ solInpl2(5.0)

# Get the sensitivities

da = sol[sol.prob.f.numindvar+1:sol.prob.f.numindvar*2,:]
db = sol[sol.prob.f.numindvar*2+1:sol.prob.f.numindvar*3,:]
dc = sol[sol.prob.f.numindvar*3+1:sol.prob.f.numindvar*4,:]

sense_res1 = [da[:,end] db[:,end] dc[:,end]]

prob = ODELocalSensitivityProblem(f.f,[1.0;1.0],(0.0,10.0),p,SensitivityAlg(autojacvec=true))
sol = solve(prob,Tsit5(),abstol=1e-14,reltol=1e-14)
x = sol[1:sol.prob.f.numindvar,:]

# Get the sensitivities

da = sol[sol.prob.f.numindvar+1:sol.prob.f.numindvar*2,:]
db = sol[sol.prob.f.numindvar*2+1:sol.prob.f.numindvar*3,:]
dc = sol[sol.prob.f.numindvar*3+1:sol.prob.f.numindvar*4,:]

sense_res2 = [da[:,end] db[:,end] dc[:,end]]

function test_f(p)
  prob = ODEProblem(f,eltype(p).([1.0,1.0]),(0.0,10.0),p)
  solve(prob,Tsit5(),abstol=1e-14,reltol=1e-14,save_everystep=false)[end]
end

p = [1.5,1.0,3.0]
fd_res = ForwardDiff.jacobian(test_f,p)
calc_res = Calculus.finite_difference_jacobian(test_f,p)

@test sense_res1 ≈ sense_res2 ≈ fd_res
@test sense_res1 ≈ sense_res2 ≈ calc_res

################################################################################

# Now do from a plain parameterized function

function f2(du,u,p,t)
  du[1] = p[1] * u[1] - p[2] * u[1]*u[2]
  du[2] = -p[3] * u[2] + u[1]*u[2]
end
p = [1.5,1.0,3.0]
prob = ODELocalSensitivityProblem(f2,[1.0;1.0],(0.0,10.0),p)
sol = solve(prob,Tsit5(),abstol=1e-14,reltol=1e-14)
res = sol[1:sol.prob.f.numindvar,:]

# Get the sensitivities

da = sol[sol.prob.f.numindvar+1:sol.prob.f.numindvar*2,:]
db = sol[sol.prob.f.numindvar*2+1:sol.prob.f.numindvar*3,:]
dc = sol[sol.prob.f.numindvar*3+1:sol.prob.f.numindvar*4,:]

sense_res = [da[:,end] db[:,end] dc[:,end]]

p = [1.5,1.0,3.0]
fd_res = ForwardDiff.jacobian(test_f,p)
calc_res = Calculus.finite_difference_jacobian(test_f,p)

@test sense_res ≈ fd_res
@test sense_res ≈ calc_res


## Check extraction

xall, dpall = extract_local_sensitivities(sol)
@test xall == res
@test dpall[1] == da

x, dp = extract_local_sensitivities(sol,length(sol.t))
sense_res2 = hcat(dp...)
@test sense_res == sense_res2

@test extract_local_sensitivities(sol,sol.t[3]) == extract_local_sensitivities(sol,3)

tmp = similar(sol[1])
@test extract_local_sensitivities(tmp,sol,sol.t[3]) == extract_local_sensitivities(sol,3)


# asmatrix=true
@test extract_local_sensitivities(sol, length(sol), true) == (x, sense_res2)
@test extract_local_sensitivities(sol, sol.t[end], true) == (x, sense_res2)
@test extract_local_sensitivities(tmp, sol, sol.t[end], true) == (x, sense_res2)


# Return type inferred
@inferred extract_local_sensitivities(sol, 1)
@inferred extract_local_sensitivities(sol, 1, Val(true))
@inferred extract_local_sensitivities(sol, sol.t[3])
@inferred extract_local_sensitivities(sol, sol.t[3], Val(true))
@inferred extract_local_sensitivities(tmp, sol, sol.t[3])
@inferred extract_local_sensitivities(tmp, sol, sol.t[3], Val(true))
