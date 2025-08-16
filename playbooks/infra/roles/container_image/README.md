<!-- DOCSIBLE START -->

# 📃 Role overview

## container_image

Description: Build and push container images using podman

### Defaults

**These are static variables with lower priority**

#### File: `defaults/main.yml

| Var          | Type         | Value       |
|--------------|--------------|-------------|
| [ci_container_registry](defaults/main.yml#L6)   | str | `quay.io/telcov10n` |
| [ci_containerfile](defaults/main.yml#L9)   | str | `Containerfile` |
| [ci_image_name](defaults/main.yml#L12)   | str |  |
| [ci_image_tags](defaults/main.yml#L15)   | list | `[]` |
| [ci_podman_build_options](defaults/main.yml#L18)   | list | `[]` |
| [ci_podman_build_options.**0**](defaults/main.yml#L19)   | str | `--platform` |
| [ci_podman_build_options.**1**](defaults/main.yml#L20)   | str | `linux/amd64` |
| [ci_podman_extra_args](defaults/main.yml#L22)   | list | `[]` |
| [ci_build_cache](defaults/main.yml#L25)   | bool | `True` |
| [ci_build_env](defaults/main.yml#L28)   | dict | `{}` |
| [ci_env_file](defaults/main.yml#L31)   | str |  |
| [ci_push](defaults/main.yml#L34)   | bool | `True` |
| [ci_debug_output](defaults/main.yml#L37)   | bool | `False` |

### Vars

**These are variables with higher priority**

#### File: vars/main.yml

| Var          | Type         | Value       |
|--------------|--------------|-------------|
| [_git_repo_root](vars/main.yml#L6)   | str | `{{ lookup('env', 'PWD') }}` |
| [_git_current_hash](vars/main.yml#L7)   | str |  |
| [_git_current_tag](vars/main.yml#L8)   | str |  |
| [_computed_image_name](vars/main.yml#L11)   | str | `{{ ci_image_name if ci_image_name else (_git_repo_root ¦ basename) }}` |
| [_repository](vars/main.yml#L12)   | str | `{{ ci_container_registry }}/{{ _computed_image_name }}` |
| [_final_tags](vars/main.yml#L15)   | str | `{{ ci_image_tags }}` |

### Tasks

#### File: tasks/build.yml

| Name | Module | Has Conditions |
| ---- | ------ | -------------- |
| Update podman build options | ansible.builtin.set_fact | True |
| Debug on vars | ansible.builtin.debug | False |
| Build container image | containers.podman.podman_image | False |
| Display build summary | ansible.builtin.debug | True |
| Verify images were built | ansible.builtin.fail | True |

#### File: tasks/git.yml

| Name | Module | Has Conditions |
| ---- | ------ | -------------- |
| Gather git repository information | block | False |
| Get git repository root | ansible.builtin.command | False |
| Get current git hash | ansible.builtin.command | False |
| Get current git tag if exists | ansible.builtin.command | False |
| Set git-derived facts | ansible.builtin.set_fact | False |
| Set final image name | ansible.builtin.set_fact | True |
| Update image tag list | ansible.builtin.set_fact | True |
| Set repository URL | ansible.builtin.set_fact | False |
| Debug git information | ansible.builtin.debug | True |

#### File: tasks/main.yml

| Name | Module | Has Conditions | Tags |
| ---- | ------ | -------------- | -----|
| Container Image Build and Push | block | False | container,build |
| Gather git information | ansible.builtin.include_tasks | False |  |
| Prepare build environment | ansible.builtin.include_tasks | False |  |
| Build container image | ansible.builtin.include_tasks | False |  |
| Push container image | ansible.builtin.include_tasks | True |  |

#### File: tasks/prepare.yml

| Name | Module | Has Conditions |
| ---- | ------ | -------------- |
| Verify containerfile exists | ansible.builtin.stat | False |
| Verify env file exists | ansible.builtin.stat | True |
| Parse environment file content | ansible.builtin.set_fact | True |
| Print contents of _env_vars | ansible.builtin.debug | False |
| Merge environment variables | ansible.builtin.set_fact | False |
| Debug build preparation | ansible.builtin.debug | True |

#### File: tasks/push.yml

| Name | Module | Has Conditions |
| ---- | ------ | -------------- |
| Push container images to registry | containers.podman.podman_image | False |
| Display push summary | ansible.builtin.debug | False |
| Verify images were pushed | ansible.builtin.fail | True |

## Task Flow Graphs

### Graph for push.yml

```mermaid
flowchart TD
Start
classDef block stroke:#3498db,stroke-width:2px;
classDef task stroke:#4b76bb,stroke-width:2px;
classDef includeTasks stroke:#16a085,stroke-width:2px;
classDef importTasks stroke:#34495e,stroke-width:2px;
classDef includeRole stroke:#2980b9,stroke-width:2px;
classDef importRole stroke:#699ba7,stroke-width:2px;
classDef includeVars stroke:#8e44ad,stroke-width:2px;
classDef rescue stroke:#665352,stroke-width:2px;

  Start-->|Task| Push_container_images_to_registry0[push container images to registry]:::task
  Push_container_images_to_registry0-->|Task| Display_push_summary1[display push summary]:::task
  Display_push_summary1-->|Task| Verify_images_were_pushed2[verify images were pushed<br>When: **item failed   default false**]:::task
  Verify_images_were_pushed2-->End
```

### Graph for prepare.yml

```mermaid
flowchart TD
Start
classDef block stroke:#3498db,stroke-width:2px;
classDef task stroke:#4b76bb,stroke-width:2px;
classDef includeTasks stroke:#16a085,stroke-width:2px;
classDef importTasks stroke:#34495e,stroke-width:2px;
classDef includeRole stroke:#2980b9,stroke-width:2px;
classDef importRole stroke:#699ba7,stroke-width:2px;
classDef includeVars stroke:#8e44ad,stroke-width:2px;
classDef rescue stroke:#665352,stroke-width:2px;

  Start-->|Task| Verify_containerfile_exists0[verify containerfile exists]:::task
  Verify_containerfile_exists0-->|Task| Verify_env_file_exists1[verify env file exists<br>When: **ci env file   default       length   0**]:::task
  Verify_env_file_exists1-->|Task| Parse_environment_file_content2[parse environment file content<br>When: **ci env file   default       length   0**]:::task
  Parse_environment_file_content2-->|Task| Print_contents_of__env_vars3[print contents of  env vars]:::task
  Print_contents_of__env_vars3-->|Task| Merge_environment_variables4[merge environment variables]:::task
  Merge_environment_variables4-->|Task| Debug_build_preparation5[debug build preparation<br>When: **ci debug output   bool**]:::task
  Debug_build_preparation5-->End
```

### Graph for git.yml

```mermaid
flowchart TD
Start
classDef block stroke:#3498db,stroke-width:2px;
classDef task stroke:#4b76bb,stroke-width:2px;
classDef includeTasks stroke:#16a085,stroke-width:2px;
classDef importTasks stroke:#34495e,stroke-width:2px;
classDef includeRole stroke:#2980b9,stroke-width:2px;
classDef importRole stroke:#699ba7,stroke-width:2px;
classDef includeVars stroke:#8e44ad,stroke-width:2px;
classDef rescue stroke:#665352,stroke-width:2px;

  Start-->|Block Start| Gather_git_repository_information0_block_start_0[[gather git repository information]]:::block
  Gather_git_repository_information0_block_start_0-->|Task| Get_git_repository_root0[get git repository root]:::task
  Get_git_repository_root0-->|Task| Get_current_git_hash1[get current git hash]:::task
  Get_current_git_hash1-->|Task| Get_current_git_tag_if_exists2[get current git tag if exists]:::task
  Get_current_git_tag_if_exists2-.->|End of Block| Gather_git_repository_information0_block_start_0
  Get_current_git_tag_if_exists2-->|Rescue Start| Gather_git_repository_information0_rescue_start_0[gather git repository information]:::rescue
  Gather_git_repository_information0_rescue_start_0-->|Task| Handle_git_command_failures0[handle git command failures]:::task
  Handle_git_command_failures0-.->|End of Rescue Block| Gather_git_repository_information0_block_start_0
  Handle_git_command_failures0-->|Task| Set_git_derived_facts1[set git derived facts]:::task
  Set_git_derived_facts1-->|Task| Set_final_image_name2[set final image name<br>When: **ci image name   default       length    0**]:::task
  Set_final_image_name2-->|Task| Update_image_tag_list3[update image tag list<br>When: **ci image tags   default       length    0**]:::task
  Update_image_tag_list3-->|Task| Set_repository_URL4[set repository url]:::task
  Set_repository_URL4-->|Task| Debug_git_information5[debug git information<br>When: **ci debug output   bool**]:::task
  Debug_git_information5-->End
```

### Graph for main.yml

```mermaid
flowchart TD
Start
classDef block stroke:#3498db,stroke-width:2px;
classDef task stroke:#4b76bb,stroke-width:2px;
classDef includeTasks stroke:#16a085,stroke-width:2px;
classDef importTasks stroke:#34495e,stroke-width:2px;
classDef includeRole stroke:#2980b9,stroke-width:2px;
classDef importRole stroke:#699ba7,stroke-width:2px;
classDef includeVars stroke:#8e44ad,stroke-width:2px;
classDef rescue stroke:#665352,stroke-width:2px;

  Start-->|Block Start| Container_Image_Build_and_Push0_block_start_0[[container image build and push]]:::block
  Container_Image_Build_and_Push0_block_start_0-->|Include task| Gather_git_information_git_yml_0[gather git information<br>include_task: git yml]:::includeTasks
  Gather_git_information_git_yml_0-->|Include task| Prepare_build_environment_prepare_yml_1[prepare build environment<br>include_task: prepare yml]:::includeTasks
  Prepare_build_environment_prepare_yml_1-->|Include task| Build_container_image_build_yml_2[build container image<br>include_task: build yml]:::includeTasks
  Build_container_image_build_yml_2-->|Include task| Push_container_image_push_yml_3[push container image<br>When: **ci push   bool**<br>include_task: push yml]:::includeTasks
  Push_container_image_push_yml_3-.->|End of Block| Container_Image_Build_and_Push0_block_start_0
  Push_container_image_push_yml_3-->End
```

### Graph for build.yml

```mermaid
flowchart TD
Start
classDef block stroke:#3498db,stroke-width:2px;
classDef task stroke:#4b76bb,stroke-width:2px;
classDef includeTasks stroke:#16a085,stroke-width:2px;
classDef importTasks stroke:#34495e,stroke-width:2px;
classDef includeRole stroke:#2980b9,stroke-width:2px;
classDef importRole stroke:#699ba7,stroke-width:2px;
classDef includeVars stroke:#8e44ad,stroke-width:2px;
classDef rescue stroke:#665352,stroke-width:2px;

  Start-->|Task| Update_podman_build_options0[update podman build options<br>When: **ci podman build options   default       length   0**]:::task
  Update_podman_build_options0-->|Task| Debug_on_vars1[debug on vars]:::task
  Debug_on_vars1-->|Task| Build_container_image2[build container image]:::task
  Build_container_image2-->|Task| Display_build_summary3[display build summary<br>When: **ci debug output   bool**]:::task
  Display_build_summary3-->|Task| Verify_images_were_built4[verify images were built<br>When: **item failed   default false**]:::task
  Verify_images_were_built4-->End
```

## Author Information

eco-ci-cd team

### License

Apache-2.0

### Minimum Ansible Version

2.15

### Platforms

- **EL**: ['8', '9']
- **Fedora**: ['38', '39']

### Dependencies

No dependencies specified.
<!-- DOCSIBLE END -->
