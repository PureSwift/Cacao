# `import Combine` for `ObservableObject` and publishers, which Cacao
# provides where there's no Combine.

cacao_add_library(Combine
  Combine.swift)

target_link_libraries(Combine PUBLIC
  Cacao)
