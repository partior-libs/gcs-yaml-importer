# gcs-yaml-importer
Convert and Import YAML configuration into flat variable in Github Action 

This action is to address reading of multi-tiers yaml config file and convert all the key values within the scope into Github flat variables (that can be assess via the jobs output)

This action will generate a executable shell script. Once the script being executed, it will populate the yaml keys and value into GitHub Actions variables

### Sample Workflow
```
name: YAML Importer

on: [push, pull_request, workflow_dispatch]

jobs:
  test-scenario-3-reader:
    runs-on: ubuntu-latest
    outputs:
      PROJECT-NAME: ${{ steps.yaml-importer.outputs.name }}
      TEST1-FLAG: ${{ steps.yaml-importer.outputs.test_test2 }}
      TEST2-FLAG: ${{ steps.yaml-importer.outputs.test_test3 }}
      TEST-CMD: ${{ steps.yaml-importer.outputs.test_cmd }}
      CI-CODESCAN: ${{ steps.yaml-importer.outputs.ci-pipeline_codescan }}
      CI-BLD-CMD: ${{ steps.yaml-importer.outputs.ci-pipeline_build-cmd }}
      CD-NPROD-ENV: ${{ steps.yaml-importer.outputs.cd-pipeline_prod-environments }}
    steps:
      - name: Test with query scope and custom importer filename
        uses: partior-libs/gcs-yaml-importer@main
        with:
          yaml-file: test-yaml/testing.yaml
          query-path: .project3
          output-file: custom-importer.sh
      - name: Start import
        id: yaml-importer
        run: |
          echo Running ...${{ steps.yaml-importer.outputs.importer-filename}}
          ${{ steps.yaml-importer.outputs.importer-filename}}

  test-scenario-3-consumer:
    runs-on: ubuntu-latest
    needs: [ test-scenario-3-reader ]
    env: 
      PROJECT_NAME: ${{ needs.test-scenario-3-reader.outputs.PROJECT-NAME }}
      TEST1_FLAG: ${{ needs.test-scenario-3-reader.outputs.TEST1-FLAG }}
      TEST2_FLAG: ${{ needs.test-scenario-3-reader.outputs.TEST2-FLAG }}
      TEST_CMD: ${{ needs.test-scenario-3-reader.outputs.TEST-CMD }}
      CI_CODESCAN: ${{ needs.test-scenario-3-reader.outputs.CI-CODESCAN }}
      CI_BLD_CMD: ${{ needs.test-scenario-3-reader.outputs.CI-BLD-CMD }}
      CD_NPROD_ENV: ${{ needs.test-scenario-3-reader.outputs.CD-NPROD-ENV }}
    steps:
      - name: Reading from previous config reader 3
        run:  |
          echo PROJECT_NAME: ${PROJECT_NAME}
          echo TEST1_FLAG: ${TEST1_FLAG}
          echo TEST2_FLAG: ${TEST2_FLAG}
          echo TEST_CMD: ${TEST_CMD}
          echo CI_CODESCAN: ${CI_CODESCAN}
          echo CI_BLD_CMD: ${CI_BLD_CMD}
          echo CD_NPROD_ENV: ${CD_NPROD_ENV}
```

### Supported inputs
```
  yaml-file:  
    description: 'Path to YAML file'
    optional: false
    default: 'default-config.yaml'
  query-path:  
    description: 'Path of config to be read'
    optional: yes
    default: '.'
  output-file:  
    description: 'Custom path of the output file'
    optional: yes
    default: 'start_import.sh'
```

### Output from the action
```
  importer-filename:
    description: "Filename of the importer script"
```