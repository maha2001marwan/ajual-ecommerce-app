import 'package:hive_ce/hive_ce.dart';

import '../models/products.dart';

// part 'hive_adapters.g.dart';

@GenerateAdapters([AdapterSpec<Product>()])
class HiveAdapters {}

//dart run build_runner build
