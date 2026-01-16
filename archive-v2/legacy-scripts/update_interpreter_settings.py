import json
import sys

try:
    with open('interpreter_settings.json') as f:
        data = json.load(f)

    spark_setting = None
    for item in data['body']:
        if item['id'] == 'spark':
            spark_setting = item
            break

    if spark_setting:
        # Update the property
        target_prop = 'zeppelin.spark.enableSupportedVersionCheck'
        if target_prop in spark_setting['properties']:
            spark_setting['properties'][target_prop]['value'] = False
            # Also update defaultValue if present in this structure (API usually returns 'value')
        else:
            # Create it
             spark_setting['properties'][target_prop] = {
                "name": target_prop,
                "value": False,
                "type": "checkbox",
                "description": "Disable check for supported spark version"
            }
        
        # Output to file
        with open('spark_setting_update.json', 'w') as f:
            json.dump(spark_setting, f)
        print("Updated spark_setting_update.json")
    else:
        print("Error: Spark setting not found")
        sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
