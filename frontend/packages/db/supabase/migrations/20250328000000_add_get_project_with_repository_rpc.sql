create or replace function get_project_with_repository(project_id bigint)
returns json
language plpgsql
security definer
as $$
begin
  return (
    select json_build_object(
      'id', p.id,
      'name', p.name,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'ProjectRepositoryMapping', (
        select json_agg(
          json_build_object(
            'id', prm.id,
            'project_id', prm.project_id,
            'repository_id', prm.repository_id,
            'created_at', prm.created_at,
            'updated_at', prm.updated_at,
            'Repository', (
              select json_build_object(
                'name', r.name,
                'owner', r.owner,
                'installation_id', r.installation_id
              )
              from "Repository" r
              where r.id = prm.repository_id
            )
          )
        )
        from "ProjectRepositoryMapping" prm
        where prm.project_id = p.id
      )
    )
    from "Project" p
    where p.id = project_id
  );
end;
$$; 