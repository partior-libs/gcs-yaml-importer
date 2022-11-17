# gcs-yaml-importer
Convert and Import YAML configuration into flat variable in Github Action 

This action is to address reading of multi-tiers yaml config file and convert all the key values within the scope into Github flat variables (that can be assess via the jobs output)

This action will generate a executable shell script. Once the script being executed, it will populate the yaml keys and value into GitHub Actions variables

### Supported inputs
```
  yaml-file:  
    description: 'Path to YAML file'
    optional: no
    default: 'default-config.yaml'
  query-path:  
    description: 'Path of config to be read'
    optional: yes
    default: '.'
  yaml-file-for-default:  
    description: 'Path to YAML file which contain default value'
    optional: yes
    default: ''
  query-path-for-default:  
    description: 'YAML query path for default value'
    optional: yes
    default: ''
  set-sub-default-keys:  
    description: 'Comma delimited sub default keys'
    optional: yes
    default: ''
  set-sub-default-keys-for-default:  
    description: 'Comma delimited sub default keys on default value file'
    optional: yes
    default: ''
  output-file:  
    description: 'Custom path of the output file'
    optional: yes
    default: 'start_import.sh'
  upload:  
    description: 'Flag to indicate if require to upload the importer file'
    optional: yes
    default: false
```

### Output from the action
```
  importer-filename:
    description: "Filename of the importer script"
```

### Sample Workflow
```
name: Test YAML Importer

on: [push, pull_request, workflow_dispatch]

env:
  CONFIG_IMPORTER_4: anyname_${{ github.run_id }}_${{ github.run_number }}
jobs:
  test-scenario-1-reader:
    runs-on: ubuntu-latest
    outputs:
      PROJECT-NAME: ${{ steps.yaml-importer.outputs.project2_name }}
      TEST1-FLAG: ${{ steps.yaml-importer.outputs.project2_test_test1 }}
      TEST2-FLAG: ${{ steps.yaml-importer.outputs.project2_test_test2 }}
      TEST-CMD: ${{ steps.yaml-importer.outputs.project2_test_cmd }}
      CI-CODESCAN: ${{ steps.yaml-importer.outputs.project2_ci-pipeline_codescan }}
      CI-BLD-CMD: ${{ steps.yaml-importer.outputs.project2_ci-pipeline_build-cmd }}
      CD-NPROD-ENV: ${{ steps.yaml-importer.outputs.project2_cd-pipeline_prod-environments }}
    steps:
      - uses: actions/checkout@v3
      - name: Test without query scope
        id: yaml-importer-creator
        uses: partior-libs/gcs-yaml-importer@partior-stable
        with:
          yaml-file: test-yaml/testing.yaml
          query-path: .
      - name: Start import
        id: yaml-importer
        run:  |
          echo Running ...${{ steps.yaml-importer-creator.outputs.importer-filename}}
          ./${{ steps.yaml-importer-creator.outputs.importer-filename}}

  test-scenario-1-consumer:
    runs-on: ubuntu-latest
    needs: [ test-scenario-1-reader ]
    env: 
      PROJECT_NAME: ${{ needs.test-scenario-1-reader.outputs.PROJECT-NAME }}
      TEST1_FLAG: ${{ needs.test-scenario-1-reader.outputs.TEST1-FLAG }}
      TEST2_FLAG: ${{ needs.test-scenario-1-reader.outputs.TEST2-FLAG }}
      TEST_CMD: ${{ needs.test-scenario-1-reader.outputs.TEST-CMD }}
      CI_CODESCAN: ${{ needs.test-scenario-1-reader.outputs.CI-CODESCAN }}
      CI_BLD_CMD: ${{ needs.test-scenario-1-reader.outputs.CI-BLD-CMD }}
      CD_NPROD_ENV: ${{ needs.test-scenario-1-reader.outputs.CD-NPROD-ENV }}
    steps:
      - name: Reading from previous config reader 1
        run:  |
          echo PROJECT_NAME: ${PROJECT_NAME}
          echo TEST1_FLAG: ${TEST1_FLAG}
          echo TEST2_FLAG: ${TEST2_FLAG}
          echo TEST_CMD: ${TEST_CMD}
          echo CI_CODESCAN: ${CI_CODESCAN}
          echo CI_BLD_CMD: ${CI_BLD_CMD}
          echo CD_NPROD_ENV: ${CD_NPROD_ENV}

  test-scenario-2-reader:
    runs-on: ubuntu-latest
    outputs:
      PROJECT-NAME: ${{ steps.yaml-importer.outputs.name }}
      TEST1-FLAG: ${{ steps.yaml-importer.outputs.test_test1 }}
      TEST2-FLAG: ${{ steps.yaml-importer.outputs.test_test2 }}
      TEST-CMD: ${{ steps.yaml-importer.outputs.test_cmd }}
      CI-CODESCAN: ${{ steps.yaml-importer.outputs.ci-pipeline_codescan }}
      CI-BLD-CMD: ${{ steps.yaml-importer.outputs.ci-pipeline_build-cmd }}
      CD-NPROD-ENV: ${{ steps.yaml-importer.outputs.cd-pipeline_prod-environments }}
    steps:
      - uses: actions/checkout@v3
      - name: Test with query scope
        id: yaml-importer-creator
        uses: partior-libs/gcs-yaml-importer@partior-stable
        with:
          yaml-file: test-yaml/testing.yaml
          query-path: .project
      - name: Start import
        id: yaml-importer
        run:  |
          echo Running ...${{ steps.yaml-importer-creator.outputs.importer-filename}}
          ./${{ steps.yaml-importer-creator.outputs.importer-filename}}

  test-scenario-2-consumer:
    runs-on: ubuntu-latest
    needs: [ test-scenario-2-reader ]
    env: 
      PROJECT_NAME: ${{ needs.test-scenario-2-reader.outputs.PROJECT-NAME }}
      TEST1_FLAG: ${{ needs.test-scenario-2-reader.outputs.TEST1-FLAG }}
      TEST2_FLAG: ${{ needs.test-scenario-2-reader.outputs.TEST2-FLAG }}
      TEST_CMD: ${{ needs.test-scenario-2-reader.outputs.TEST-CMD }}
      CI_CODESCAN: ${{ needs.test-scenario-2-reader.outputs.CI-CODESCAN }}
      CI_BLD_CMD: ${{ needs.test-scenario-2-reader.outputs.CI-BLD-CMD }}
      CD_NPROD_ENV: ${{ needs.test-scenario-2-reader.outputs.CD-NPROD-ENV }}
    steps:
      - name: Reading from previous config reader 2
        run:  |
          echo PROJECT_NAME: ${PROJECT_NAME}
          echo TEST1_FLAG: ${TEST1_FLAG}
          echo TEST2_FLAG: ${TEST2_FLAG}
          echo TEST_CMD: ${TEST_CMD}
          echo CI_CODESCAN: ${CI_CODESCAN}
          echo CI_BLD_CMD: ${CI_BLD_CMD}
          echo CD_NPROD_ENV: ${CD_NPROD_ENV}

  test-scenario-3-reader:
    runs-on: ubuntu-latest
    outputs:
      PROJECT-NAME: ${{ steps.yaml-importer.outputs.name }}
      TEST1-FLAG: ${{ steps.yaml-importer.outputs.test_test1 }}
      TEST2-FLAG: ${{ steps.yaml-importer.outputs.test_test2 }}
      TEST-CMD: ${{ steps.yaml-importer.outputs.test_cmd }}
      CI-CODESCAN: ${{ steps.yaml-importer.outputs.ci-pipeline_codescan }}
      CI-BLD-CMD: ${{ steps.yaml-importer.outputs.ci-pipeline_build-cmd }}
      CD-NPROD-ENV: ${{ steps.yaml-importer.outputs.cd-pipeline_prod-environments }}
    steps:
      - uses: actions/checkout@v3
      - name: Test with query scope and custom importer filename
        id: yaml-importer-creator
        uses: partior-libs/gcs-yaml-importer@partior-stable
        with:
          yaml-file: test-yaml/testing.yaml
          query-path: .project3
          output-file: custom-importer.sh
      - name: Start import
        id: yaml-importer
        run: |
          echo Running ...${{ steps.yaml-importer-creator.outputs.importer-filename}}
          ./${{ steps.yaml-importer-creator.outputs.importer-filename}}

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

  test-scenario-4-reader:
    runs-on: ubuntu-latest
    outputs:
      CONFIG_IMPORTER: ./${{ steps.yaml-importer-creator.outputs.importer-filename}}
    steps:
      - uses: actions/checkout@v3
      - name: Test with upload flag
        id: yaml-importer-creator
        uses: partior-libs/gcs-yaml-importer@partior-stable
        with:
          yaml-file: test-yaml/testing.yaml
          query-path: .project4
          output-file: ${{ env.CONFIG_IMPORTER_4 }}
          yaml-file-for-default: test-yaml/testing.yaml
          query-path-for-default: .default
          upload: true

  test-scenario-4-consumer:
    runs-on: ubuntu-latest
    needs: [ test-scenario-4-reader ]
    steps:
      - uses: actions/download-artifact@v2
        with:
          name: ${{ env.CONFIG_IMPORTER_4 }}
      - name: Start import
        id: yml-config
        run: |
          echo Importing ...${{ env.CONFIG_IMPORTER_4 }}
          source ./${{ env.CONFIG_IMPORTER_4 }}   

      - name: Reading from previous config reader 4
        run:  |
          echo PROJECT_NAME: ${{ steps.yml-config.outputs.name }}
          echo PROJECT_NAME4: ${{ steps.yml-config.outputs.name4 }}
          echo TEST1_FLAG: ${{ steps.yml-config.outputs.test_test1 }}
          echo TEST2_FLAG: ${{ steps.yml-config.outputs.test_test2 }}
          echo TEST_CMD: ${{ steps.yml-config.outputs.test_cmd }}
          echo CI_CODESCAN: ${{ steps.yml-config.outputs.ci-pipeline_codescan }}
          echo CI_BLD_CMD: ${{ steps.yml-config.outputs.ci-pipeline_build-cmd }}
          echo CD_NPROD_ENV: ${{ steps.yml-config.outputs.cd-pipeline_prod-environments }}

```

