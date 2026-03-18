module%shared Config = struct
  let initial_creet_count = 5
  let initial_global_speed = 1.
  let max_global_speed = 1.5
  let initial_creet_speed = 1.
  let initial_creet_size = 80.
  let berserk_size = initial_creet_size *. 4.
  let mean_size = initial_creet_size *. 0.85
  let creet_reproduce_count = 1000
end