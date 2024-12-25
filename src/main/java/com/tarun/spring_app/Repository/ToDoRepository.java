package com.tarun.spring_app.Repository;

import com.tarun.spring_app.Entity.ToDo;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ToDoRepository extends JpaRepository<ToDo, Long> {}
