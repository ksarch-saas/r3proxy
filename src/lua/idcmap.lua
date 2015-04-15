
primary = {
   tc = {"$master"},
   jx = {"$master"},
   nj02 = {"$master"},
   nj03 = {"$master"},
   hz01 = {"$master"},
}

primary_preferred = {
   tc = {"$master","tc","jx",{"nj02","nj03","hz01"}},
   jx = {"$master","jx","tc",{"nj02","nj03","hz01"}},
   nj02 = {"$master","nj02","nj03","hz01",{"tc","jx"}},
   nj03 = {"$master","nj03","nj02","hz01",{"tc","jx"}},
   hz01 = {"$master","hz01",{"nj02","nj03"},{"tc","jx"}}
}

nearest = {
   tc = {"tc","jx",{"nj02","nj03","hz01"}},
   jx = {"jx","tc",{"nj02","nj03","hz01"}},
   nj02 = {"nj02","nj03","hz01",{"tc","jx"}},
   nj03 = {"nj03","nj02","hz01",{"tc","jx"}},
   hz01 = {"hz01",{"nj02","nj03"},{"tc","jx"}}
}

return nearest
